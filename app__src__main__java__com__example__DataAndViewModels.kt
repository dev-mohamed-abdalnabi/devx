package com.example

import android.media.AudioAttributes
import android.media.MediaPlayer
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.launch
import org.json.JSONArray
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// --- API Models ---
@JsonClass(generateAdapter = true) data class AladhanResponse(@Json(name = "data") val data: AladhanData)
@JsonClass(generateAdapter = true) data class AladhanData(@Json(name = "timings") val timings: Map<String, String>, @Json(name = "date") val date: AladhanDate)
@JsonClass(generateAdapter = true) data class AladhanDate(@Json(name = "hijri") val hijri: HijriDate)
@JsonClass(generateAdapter = true) data class HijriDate(@Json(name = "day") val day: String, @Json(name = "month") val month: HijriMonth, @Json(name = "year") val year: String)
@JsonClass(generateAdapter = true) data class HijriMonth(@Json(name = "ar") val ar: String)

interface AladhanApi {
    @GET("timingsByCity")
    suspend fun getTimings(@Query("city") city: String = "Cairo", @Query("country") country: String = "Egypt", @Query("method") method: Int = 5): AladhanResponse
}

@JsonClass(generateAdapter = true) data class QuranSurahResponse(@Json(name = "data") val data: List<Surah>)
@JsonClass(generateAdapter = true) data class Surah(val number: Int, val name: String, val englishName: String, val numberOfAyahs: Int, val revelationType: String)

@JsonClass(generateAdapter = true) data class SurahDetailResponse(@Json(name = "data") val data: SurahDetail)
@JsonClass(generateAdapter = true) data class SurahDetail(val number: Int, val name: String, val ayahs: List<Ayah>)
@JsonClass(generateAdapter = true) data class Ayah(val numberInSurah: Int, val text: String, val audio: String? = null)

interface AlQuranApi {
    @GET("surah") suspend fun getAllSurahs(): QuranSurahResponse
    @GET("surah/{number}") suspend fun getSurah(@Path("number") number: Int): SurahDetailResponse
    @GET("surah/{number}/ar.alafasy") suspend fun getSurahAudio(@Path("number") number: Int): SurahDetailResponse
}

@JsonClass(generateAdapter = true) data class GeminiRequest(val contents: List<GeminiContent>)
@JsonClass(generateAdapter = true) data class GeminiContent(val parts: List<GeminiPart>, val role: String? = null)
@JsonClass(generateAdapter = true) data class GeminiPart(val text: String)
@JsonClass(generateAdapter = true) data class GeminiResponse(val candidates: List<GeminiCandidate>?)
@JsonClass(generateAdapter = true) data class GeminiCandidate(val content: GeminiContent?)

interface GeminiApiService {
    @POST("v1beta/models/gemini-3.5-flash:generateContent")
    suspend fun generateContent(@Query("key") apiKey: String, @Body request: GeminiRequest): GeminiResponse
}

object ApiClient {
    private val moshi = Moshi.Builder().add(KotlinJsonAdapterFactory()).build()
    val aladhanApi: AladhanApi by lazy { Retrofit.Builder().baseUrl("https://api.aladhan.com/v1/").addConverterFactory(MoshiConverterFactory.create(moshi)).build().create(AladhanApi::class.java) }
    val alQuranApi: AlQuranApi by lazy { Retrofit.Builder().baseUrl("https://api.alquran.cloud/v1/").addConverterFactory(MoshiConverterFactory.create(moshi)).build().create(AlQuranApi::class.java) }
    val geminiApi: GeminiApiService by lazy { Retrofit.Builder().baseUrl("https://generativelanguage.googleapis.com/").addConverterFactory(MoshiConverterFactory.create(moshi)).build().create(GeminiApiService::class.java) }
}

// --- ViewModels ---

class MainViewModel : ViewModel() {
    var topBarText by mutableStateOf("جاري التحميل...")
        private set
    var hijriDateText by mutableStateOf("جاري التحميل...")
        private set

    init {
        viewModelScope.launch {
            try {
                val response = ApiClient.aladhanApi.getTimings()
                topBarText = getNextPrayer(response.data.timings)
                val h = response.data.date.hijri
                hijriDateText = "${h.day} ${h.month.ar} ${h.year}"
            } catch (e: Exception) {
                topBarText = "الفجر 04:30"
                hijriDateText = "14 رمضان 1445"
            }
        }
    }
    private fun getNextPrayer(timings: Map<String, String>): String {
        val f = SimpleDateFormat("HH:mm", Locale.ENGLISH)
        val current = f.format(Date())
        val prayers = mapOf("Fajr" to "الفجر", "Dhuhr" to "الظهر", "Asr" to "العصر", "Maghrib" to "المغرب", "Isha" to "العشاء")
        for ((k, name) in prayers) {
            val t = timings[k] ?: continue
            if (t > current) return "الصلاة القادمة: $name $t"
        }
        return "الصلاة القادمة: الفجر ${timings["Fajr"] ?: "04:30"}"
    }
}

class QuranViewModel : ViewModel() {
    var surahs by mutableStateOf<List<Surah>>(emptyList())
        private set
    var isLoading by mutableStateOf(true)
        private set

    init {
        viewModelScope.launch {
            try {
                surahs = ApiClient.alQuranApi.getAllSurahs().data
            } catch (e: Exception) { } finally { isLoading = false }
        }
    }
}

class SurahDetailViewModel : ViewModel() {
    var surahDetail by mutableStateOf<SurahDetail?>(null)
        private set
    var isLoading by mutableStateOf(true)
        private set
    fun loadSurah(number: Int) {
        isLoading = true
        viewModelScope.launch {
            try { surahDetail = ApiClient.alQuranApi.getSurah(number).data } catch (e: Exception) { } finally { isLoading = false }
        }
    }
}

class AudioPlayerViewModel : ViewModel() {
    var selectedSurah by mutableStateOf<SurahDetail?>(null)
    var isPlaying by mutableStateOf(false)
    var currentAyahIndex by mutableStateOf(0)
    var isLoading by mutableStateOf(true)
    private var mediaPlayer: MediaPlayer? = null

    init { loadSurahAudio(1) }

    private fun loadSurahAudio(number: Int) {
        isLoading = true
        stopAudio()
        viewModelScope.launch {
            try {
                selectedSurah = ApiClient.alQuranApi.getSurahAudio(number).data
                currentAyahIndex = 0
                playCurrentAyah()
            } catch (e: Exception) { } finally { isLoading = false }
        }
    }

    private fun playCurrentAyah() {
        val audioUrl = selectedSurah?.ayahs?.getOrNull(currentAyahIndex)?.audio ?: return
        mediaPlayer?.release()
        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            try {
                setDataSource(audioUrl)
                prepareAsync()
                setOnPreparedListener { start(); this@AudioPlayerViewModel.isPlaying = true }
                setOnCompletionListener {
                    if (currentAyahIndex < (selectedSurah?.ayahs?.size ?: 0) - 1) { currentAyahIndex++; playCurrentAyah() } else { this@AudioPlayerViewModel.isPlaying = false }
                }
            } catch (e: Exception) {}
        }
    }

    fun togglePlayPause() {
        mediaPlayer?.let {
            if (it.isPlaying) { it.pause(); isPlaying = false } else { it.start(); isPlaying = true }
        } ?: playCurrentAyah()
    }
    fun nextAyah() { if (currentAyahIndex < (selectedSurah?.ayahs?.size ?: 0) - 1) { currentAyahIndex++; playCurrentAyah() } }
    fun previousAyah() { if (currentAyahIndex > 0) { currentAyahIndex--; playCurrentAyah() } }
    fun stopAudio() { mediaPlayer?.release(); mediaPlayer = null; isPlaying = false }
}

class ChatMessage(val text: String, val isUser: Boolean)
class TafseerViewModel : ViewModel() {
    var messages = mutableStateListOf<ChatMessage>()
        private set
    var isLoading by mutableStateOf(false)
        private set
    init { messages.add(ChatMessage("السلام عليكم، أنا المساعد الذكي لتفسير القرآن وعلوم الدين. كيف يمكنني مساعدتك اليوم؟", false)) }
    fun sendMessage(text: String) {
        if (text.isBlank()) return
        messages.add(ChatMessage(text, true))
        isLoading = true
        val apiKey = try { BuildConfig::class.java.getField("GEMINI_API_KEY").get(null) as String } catch (e: Exception) { "" }
        if (apiKey.isBlank()) { messages.add(ChatMessage("عذراً، لم يتم العثور على مفتاح API.", false)); isLoading = false; return }
        viewModelScope.launch {
            try {
                val contents = messages.map { GeminiContent(parts = listOf(GeminiPart(text = it.text)), role = if (it.isUser) "user" else "model") }
                val resp = ApiClient.geminiApi.generateContent(apiKey, GeminiRequest(contents))
                val reply = resp.candidates?.firstOrNull()?.content?.parts?.firstOrNull()?.text ?: "لا يوجد رد."
                messages.add(ChatMessage(reply, false))
            } catch (e: Exception) { messages.add(ChatMessage("حدث خطأ: ${e.message}", false)) } finally { isLoading = false }
        }
    }
}

data class DynamicItem(val text: String, val subtitle: String)
class DynamicListViewModel : ViewModel() {
    var items by mutableStateOf<List<DynamicItem>>(emptyList())
        private set
    var isLoading by mutableStateOf(true)
        private set

    fun loadContent(topic: String) {
        isLoading = true
        val apiKey = try { BuildConfig::class.java.getField("GEMINI_API_KEY").get(null) as String } catch (e: Exception) { "" }
        if (apiKey.isBlank()) { items = listOf(DynamicItem("يرجى إضافة مفتاح Gemini API لجلب البيانات.", "خطأ")); isLoading = false; return }
        viewModelScope.launch {
            try {
                val prompt = "أنت خبير إسلامي. قم بإعطائي 10 من $topic باللغة العربية. يجب أن يكون الرد عبارة عن مصفوفة JSON فقط تحتوي على كائنات بها حقل 'text' للنص، وحقل 'subtitle' للمصدر أو التكرار. لا تقم بإضافة أي نص آخر أو علامات Markdown."
                val resp = ApiClient.geminiApi.generateContent(apiKey, GeminiRequest(listOf(GeminiContent(listOf(GeminiPart(prompt))))))
                var reply = resp.candidates?.firstOrNull()?.content?.parts?.firstOrNull()?.text ?: "[]"
                reply = reply.trim().removePrefix("```json").removePrefix("```").removeSuffix("```").trim()
                val jsonArray = JSONArray(reply)
                val parsedItems = mutableListOf<DynamicItem>()
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    parsedItems.add(DynamicItem(obj.optString("text", ""), obj.optString("subtitle", "")))
                }
                items = parsedItems
            } catch (e: Exception) { items = listOf(DynamicItem("حدث خطأ أثناء جلب البيانات.", "")) } finally { isLoading = false }
        }
    }
}
