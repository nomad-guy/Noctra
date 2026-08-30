package com.example.noctra

import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.DESKeySpec

object JioSaavnNativeEngine {
    private const val DES_KEY = "38346591"

    fun decryptMediaUrl(encryptedMediaUrl: String?): String? {
        if (encryptedMediaUrl.isNullOrEmpty()) return null
        return try {
            val keySpec = DESKeySpec(DES_KEY.toByteArray(Charsets.UTF_8))
            val keyFactory = SecretKeyFactory.getInstance("DES")
            val key = keyFactory.generateSecret(keySpec)

            val cipher = Cipher.getInstance("DES/ECB/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, key)

            val encBytes = Base64.decode(encryptedMediaUrl.trim(), Base64.DEFAULT)
            val decBytes = cipher.doFinal(encBytes)
            var rawUrl = String(decBytes, Charsets.UTF_8).trim()

            if (rawUrl.startsWith("http://")) {
                rawUrl = "https://" + rawUrl.substring(7)
            }

            rawUrl.replace("_96.mp4", "_320.mp4")
                .replace("_96.m4a", "_320.m4a")
                .replace("_160.mp4", "_320.mp4")
                .replace("_160.m4a", "_320.m4a")
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    fun searchSongs(query: String, limit: Int = 20): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        try {
            val encodedQuery = URLEncoder.encode(query, "UTF-8")
            val urlString = "https://www.jiosaavn.com/api.php?__call=search.getResults&q=$encodedQuery&_format=json&_marker=0&api_version=4&ctx=android&n=$limit"
            val jsonStr = httpGet(urlString) ?: return results

            val jsonObj = JSONObject(jsonStr)
            val items = jsonObj.optJSONArray("results") ?: return results

            for (i in 0 until items.length()) {
                val item = items.optJSONObject(i) ?: continue
                val parsed = parseSongItem(item)
                if (parsed != null) results.add(parsed)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return results
    }

    fun resolveTrackStream(title: String, artist: String): String? {
        val q1 = "$title $artist".trim()
        val songs1 = searchSongs(q1, 5)
        if (songs1.isNotEmpty()) {
            val sUrl = songs1[0]["stream_url"] as? String
            if (!sUrl.isNullOrEmpty()) return sUrl
        }

        val q2 = title.trim()
        val songs2 = searchSongs(q2, 5)
        if (songs2.isNotEmpty()) {
            val sUrl = songs2[0]["stream_url"] as? String
            if (!sUrl.isNullOrEmpty()) return sUrl
        }

        return null
    }

    private fun parseSongItem(item: JSONObject): Map<String, Any?>? {
        val rawTitle = item.optString("title", item.optString("song", ""))
        if (rawTitle.isEmpty()) return null

        val cleanTitle = rawTitle.replace("&quot;", "\"").replace("&#039;", "'").replace("&amp;", "&")
        val moreInfo = item.optJSONObject("more_info")
        val encryptedUrl = moreInfo?.optString("encrypted_media_url", "") ?: ""
        val streamUrl = decryptMediaUrl(encryptedUrl)

        val rawArtist = item.optString("subtitle", "")
        val cleanArtist = if (rawArtist.isNotEmpty()) {
            rawArtist.replace("&quot;", "\"").replace("&#039;", "'").replace("&amp;", "&")
        } else {
            val artistMap = moreInfo?.optJSONObject("artistMap")
            val primary = artistMap?.optJSONArray("primary_artists")
            if (primary != null && primary.length() > 0) {
                primary.optJSONObject(0)?.optString("name", "Popular Artist") ?: "Popular Artist"
            } else "Popular Artist"
        }

        val rawImg = item.optString("image", "")
        var highResImg = rawImg.replace("150x150", "500x500").replace("50x50", "500x500")
        if (highResImg.startsWith("http://")) {
            highResImg = "https://" + highResImg.substring(7)
        }
        val durationStr = moreInfo?.optString("duration", "180") ?: "180"
        val durationSec = durationStr.toIntOrNull() ?: 180

        return mapOf(
            "id" to "saavn_${item.optString("id", cleanTitle.hashCode().toString())}",
            "title" to cleanTitle,
            "artist" to cleanArtist,
            "album" to (moreInfo?.optString("album", "CD Master Edition") ?: "CD Master Edition"),
            "thumbnail" to highResImg,
            "stream_url" to (streamUrl ?: ""),
            "duration" to durationSec,
            "source" to "JioSaavn 320kbps CD Lossless"
        )
    }

    private fun httpGet(urlString: String): String? {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(urlString)
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 5000
            conn.readTimeout = 6000
            conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

            if (conn.responseCode == 200) {
                val reader = BufferedReader(InputStreamReader(conn.inputStream, "UTF-8"))
                val sb = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    sb.append(line)
                }
                reader.close()
                sb.toString()
            } else null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        } finally {
            conn?.disconnect()
        }
    }
}
