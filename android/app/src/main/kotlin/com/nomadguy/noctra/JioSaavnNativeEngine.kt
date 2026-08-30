package com.nomadguy.noctra

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

            if (rawUrl.startsWith("http://") && !rawUrl.contains("127.0.0.1") && !rawUrl.contains("localhost")) {
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

    private fun sanitizeText(input: String): String {
        val normalized = java.text.Normalizer.normalize(input, java.text.Normalizer.Form.NFD)
        val withoutAccents = normalized.replace(Regex("\\p{InCombiningDiacriticalMarks}+"), "")
        return withoutAccents
            .replace(Regex("(?i)\\s*-\\s*topic"), "")
            .replace(Regex("(?i)\\(official.*?\\)"), "")
            .replace(Regex("(?i)\\[official.*?\\]"), "")
            .replace(Regex("(?i)\\(audio\\)"), "")
            .replace(Regex("(?i)\\(lyrics\\)"), "")
            .replace(Regex("(?i)\\(video\\)"), "")
            .replace(Regex("(?i)\\(slowed.*?\\)"), "")
            .replace(Regex("(?i)\\(speed.*?\\)"), "")
            .replace(Regex("[^a-zA-Z0-9\\s]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    fun searchSongs(query: String, limit: Int = 20): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val cleanQ = sanitizeText(query)
        val queriesToTry = if (cleanQ.isNotEmpty() && cleanQ != query) listOf(cleanQ, query) else listOf(query)

        for (q in queriesToTry) {
            try {
                val encodedQuery = URLEncoder.encode(q, "UTF-8")
                val urlString = "https://www.jiosaavn.com/api.php?__call=search.getResults&q=$encodedQuery&_format=json&_marker=0&api_version=4&ctx=android&n=$limit"
                val jsonStr = httpGet(urlString) ?: continue

                val jsonObj = JSONObject(jsonStr)
                val items = jsonObj.optJSONArray("results") ?: continue

                for (i in 0 until items.length()) {
                    val item = items.optJSONObject(i) ?: continue
                    val parsed = parseSongItem(item)
                    if (parsed != null && !results.any { it["id"] == parsed["id"] }) {
                        results.add(parsed)
                    }
                }
                if (results.isNotEmpty()) break
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return results
    }

    private fun isMatch(targetTitle: String, candidateTitle: String): Boolean {
        val tTokens = sanitizeText(targetTitle).lowercase().split(" ").filter { it.length > 1 }
        val cTokens = sanitizeText(candidateTitle).lowercase().split(" ").filter { it.length > 1 }
        if (tTokens.isEmpty() || cTokens.isEmpty()) return false
        val tFull = tTokens.joinToString(" ")
        val cFull = cTokens.joinToString(" ")
        if (tFull == cFull || cFull.contains(tFull) || tFull.contains(cFull)) return true
        val matchCount = tTokens.count { token -> cTokens.any { it.contains(token) || token.contains(it) } }
        return (matchCount.toDouble() / tTokens.size.toDouble()) >= 0.5
    }

    fun resolveTrackStream(title: String, artist: String): String? {
        val cleanT = sanitizeText(title)
        val cleanA = sanitizeText(artist.split(Regex("[,&/]")).firstOrNull() ?: "")

        val permutations = mutableListOf<String>()
        if (cleanT.isNotEmpty() && cleanA.isNotEmpty()) permutations.add("$cleanT $cleanA")
        if (cleanT.isNotEmpty()) permutations.add(cleanT)
        if (title.isNotEmpty() && artist.isNotEmpty()) permutations.add("$title $artist")
        if (title.isNotEmpty()) permutations.add(title)

        for (p in permutations) {
            val songs = searchSongs(p, 6)
            for (s in songs) {
                val sTitle = s["title"] as? String ?: ""
                val sUrl = s["stream_url"] as? String
                if (!sUrl.isNullOrEmpty() && isMatch(title, sTitle)) {
                    return sUrl
                }
            }
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
