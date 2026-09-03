package com.nomadguy.noctra

import android.util.Base64
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
        } catch (_: Throwable) { null }
    }

    fun extractInnerTubeStream(videoId: String): String? {
        if (videoId.length != 11) return null
        val clients = listOf(
            mapOf("clientName" to "ANDROID_TESTSUITE", "clientVersion" to "1.9", "androidSdkVersion" to 30),
            mapOf("clientName" to "ANDROID_MUSIC", "clientVersion" to "6.42.52", "androidSdkVersion" to 34),
            mapOf("clientName" to "TVHTML5", "clientVersion" to "7.20240801.12.00", "theme" to "TVHTML5")
        )
        for (client in clients) {
            try {
                val body = JSONObject().apply {
                    put("videoId", videoId)
                    put("context", JSONObject().apply { put("client", JSONObject(client)) })
                }
                val jsonStr = httpPost("https://music.youtube.com/youtubei/v1/player", body.toString()) ?: continue
                val root = JSONObject(jsonStr)
                val formats = root.optJSONObject("streamingData")?.optJSONArray("adaptiveFormats") ?: continue
                var bestUrl: String? = null
                var maxBitrate = 0
                for (i in 0 until formats.length()) {
                    val f = formats.getJSONObject(i)
                    val mime = f.optString("mimeType", "")
                    val bitrate = f.optInt("bitrate", 0)
                    val url = f.optString("url", "")
                    if (mime.contains("audio") && url.isNotEmpty() && bitrate > maxBitrate) {
                        maxBitrate = bitrate
                        bestUrl = url
                    }
                }
                if (!bestUrl.isNullOrEmpty()) return bestUrl
            } catch (_: Throwable) {}
        }
        return null
    }

    fun fetchRadioTracks(videoId: String): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        try {
            val body = JSONObject().apply {
                put("videoId", videoId)
                put("context", JSONObject().apply {
                    put("client", JSONObject(mapOf("clientName" to "WEB_REMIX", "clientVersion" to "1.20240820.01.00", "hl" to "en", "gl" to "US")))
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
        } catch (_: Throwable) {}
        return list
    }

    private fun httpPost(urlStr: String, jsonBody: String): String? {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(urlStr)
            conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 4000
                readTimeout = 4000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("User-Agent", "Mozilla/5.0")
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
        } catch (_: Throwable) { null } finally { conn?.disconnect() }
    }
}
