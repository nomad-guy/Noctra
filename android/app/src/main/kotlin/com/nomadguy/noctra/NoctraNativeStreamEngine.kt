package com.nomadguy.noctra

import android.util.Base64
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.DESKeySpec

object NoctraNativeStreamEngine {
    private const val TAG = "NoctraNativeStream"
    private const val DES_KEY = "38346591"

    fun decryptJioSaavnUrl(encUrl: String?): String? {
        if (encUrl.isNullOrEmpty()) return null
        return try {
            val keySpec = DESKeySpec(DES_KEY.toByteArray(Charsets.UTF_8))
            val key = SecretKeyFactory.getInstance("DES").generateSecret(keySpec)
            val cipher = Cipher.getInstance("DES/ECB/PKCS5Padding").apply { init(Cipher.DECRYPT_MODE, key) }
            val decBytes = cipher.doFinal(Base64.decode(encUrl.trim(), Base64.DEFAULT))
            var raw = String(decBytes, Charsets.UTF_8).trim()
            if (raw.startsWith("http://") && !raw.contains("127.0.0.1") && !raw.contains("localhost")) {
                raw = "https://" + raw.substring(7)
            }
            raw.replace("_96.mp4", "_320.mp4").replace("_96.m4a", "_320.m4a").replace("_160.mp4", "_320.mp4").replace("_160.m4a", "_320.m4a")
        } catch (e: Throwable) {
            Log.w(TAG, "decryptJioSaavnUrl failed", e)
            null
        }
    }

    fun extractInnerTubeStream(videoId: String): String? {
        if (videoId.length != 11) return null
        // Direct-URL clients only (see the Dart catalog for the rationale):
        // retired ANDROID_TESTSUITE and the version-gated / cipher-only
        // clients were removed. VISIONOS is tried first, ANDROID_VR 1.65.10
        // second — both return pre-signed audio urls with no deciphering.
        val clients = listOf(
            mapOf(
                "clientName" to "VISIONOS", "clientVersion" to "0.1", "clientId" to "101",
                "userAgent" to "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
                "osName" to "visionOS", "osVersion" to "1.3.21O771",
                "deviceMake" to "Apple", "deviceModel" to "RealityDevice14,1"
            ),
            mapOf(
                "clientName" to "ANDROID_VR", "clientVersion" to "1.65.10", "clientId" to "28",
                "userAgent" to "com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
                "osName" to "Android", "osVersion" to "12L",
                "deviceMake" to "Oculus", "deviceModel" to "Quest 3", "androidSdkVersion" to 32
            )
        )
        for (client in clients) {
            try {
                val clientJson = JSONObject(client)
                val body = JSONObject().apply {
                    put("videoId", videoId)
                    put("context", JSONObject().apply {
                        put("client", JSONObject().apply {
                            put("clientName", clientJson.optString("clientName"))
                            put("clientVersion", clientJson.optString("clientVersion"))
                            for (key in listOf("osName", "osVersion", "deviceMake", "deviceModel", "androidSdkVersion")) {
                                if (clientJson.has(key)) put(key, clientJson.get(key))
                            }
                        })
                    })
                }
                val headers = mapOf(
                    "X-Goog-Api-Format-Version" to "1",
                    "X-YouTube-Client-Name" to clientJson.optString("clientId"),
                    "X-YouTube-Client-Version" to clientJson.optString("clientVersion"),
                    "Origin" to "https://music.youtube.com",
                    "Referer" to "https://music.youtube.com/"
                )
                val jsonStr = httpPost(
                    "https://music.youtube.com/youtubei/v1/player",
                    body.toString(),
                    clientJson.optString("userAgent"),
                    headers
                ) ?: continue
                val root = JSONObject(jsonStr)
                val ps = root.optJSONObject("playabilityStatus")
                val status = ps?.optString("status", "") ?: ""
                if (status != "OK") {
                    // A permanent source-level refusal affects the next client
                    // of the same source too; do not keep probing.
                    val reason = (ps?.optString("reason", "") ?: "").lowercase()
                    if (reason.contains("sign in") || reason.contains("age") ||
                        reason.contains("unavailable") || reason.contains("not available")
                    ) {
                        return null
                    }
                    continue
                }
                val formats = root.optJSONObject("streamingData")?.optJSONArray("adaptiveFormats") ?: continue
                var bestUrl: String? = null
                var maxBitrate = 0
                for (i in 0 until formats.length()) {
                    val f = formats.getJSONObject(i)
                    val mime = f.optString("mimeType", "")
                    val bitrate = f.optInt("bitrate", 0)
                    val url = f.optString("url", "")
                    if (mime.contains("audio") && url.startsWith("https://") && bitrate > maxBitrate) {
                        maxBitrate = bitrate
                        bestUrl = url
                    }
                }
                if (!bestUrl.isNullOrEmpty()) return bestUrl
            } catch (e: Throwable) {
                Log.w(TAG, "extractInnerTubeStream client failed for $videoId", e)
            }
        }
        return null
    }

    fun fetchRadioTracks(videoId: String): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        try {
            val body = JSONObject().apply {
                put("videoId", videoId)
                put("context", JSONObject().apply {
                    put("client", JSONObject(mapOf("clientName" to "WEB_REMIX", "clientVersion" to "1.20260213.01.00", "hl" to "en", "gl" to "US")))
                })
            }
            val jsonStr = httpPost("https://music.youtube.com/youtubei/v1/next", body.toString()) ?: return list
            val root = JSONObject(jsonStr)
            val tabs = root.optJSONObject("contents")?.optJSONObject("singleColumnMusicWatchNextResultsRenderer")?.optJSONObject("tabbedRenderer")?.optJSONObject("watchNextTabbedResultsRenderer")?.optJSONArray("tabs")
            val contents = tabs?.optJSONObject(0)?.optJSONObject("tabRenderer")?.optJSONObject("content")?.optJSONObject("musicQueueRenderer")?.optJSONObject("content")?.optJSONObject("playlistPanelRenderer")?.optJSONArray("contents") ?: return list

            for (i in 0 until contents.length()) {
                val item = contents.optJSONObject(i)?.optJSONObject("playlistPanelVideoRenderer") ?: continue
                val vid = item.optString("videoId", "")
                val title = item.optJSONObject("title")?.optJSONArray("runs")?.optJSONObject(0)?.optString("text", "") ?: ""
                val artist = item.optJSONObject("longBylineText")?.optJSONArray("runs")?.optJSONObject(0)?.optString("text", "YouTube Music") ?: "YouTube Music"
                val durStr = item.optJSONObject("lengthText")?.optJSONArray("runs")?.optJSONObject(0)?.optString("text", "3:30") ?: "3:30"
                if (vid.isNotEmpty() && title.isNotEmpty()) {
                    list.add(mapOf("id" to vid, "title" to title, "artist" to artist, "duration" to durStr, "thumbnail" to "https://i.ytimg.com/vi/$vid/hqdefault.jpg"))
                }
            }
            if (contents.length() == 0) {
                Log.w(TAG, "fetchRadioTracks: empty playlistPanelRenderer for $videoId — response shape may have changed")
            }
        } catch (e: Throwable) {
            Log.w(TAG, "fetchRadioTracks failed for $videoId", e)
        }
        return list
    }

    private fun httpPost(
        urlStr: String,
        jsonBody: String,
        userAgent: String = "Mozilla/5.0",
        extraHeaders: Map<String, String> = emptyMap()
    ): String? {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(urlStr)
            conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 4000
                readTimeout = 4000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("User-Agent", userAgent)
                for ((key, value) in extraHeaders) {
                    setRequestProperty(key, value)
                }
            }
            OutputStreamWriter(conn.outputStream).use { it.write(jsonBody); it.flush() }
            if (conn.responseCode == 200) {
                BufferedReader(InputStreamReader(conn.inputStream, "UTF-8")).use { reader ->
                    val sb = StringBuilder()
                    val buffer = CharArray(4096)
                    var read: Int
                    val maxChars = 2 * 1024 * 1024
                    while (reader.read(buffer).also { read = it } != -1) {
                        if (sb.length + read > maxChars) {
                            sb.append(buffer, 0, maxChars - sb.length)
                            break
                        }
                        sb.append(buffer, 0, read)
                    }
                    sb.toString()
                }
            } else null
        } catch (e: Throwable) {
            val status = runCatching { conn?.responseCode ?: -1 }.getOrDefault(-1)
            Log.w(TAG, "httpPost $urlStr failed (status=$status)", e)
            null
        } finally { conn?.disconnect() }
    }
}
