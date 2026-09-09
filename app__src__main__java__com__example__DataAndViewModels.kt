package com.example

import android.media.AudioAttributes
import android.media.MediaPlayer
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import kotlinx.coroutines.launch
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// --- API Models (كل الداتا جايه من APIs رسمية عامة، مفيش أي Gemini/AI هنا) ---
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
    // edition قابلة للتغيير عشان يبقى فيه اختيار شيخ
    @GET("surah/{number}/{edition}") suspend fun getSurahAudio(@Path("number") number: Int, @Path("edition") edition: String = "ar.alafasy"): SurahDetailResponse
    // تفسير الميسر - API رسمي عام (alquran.cloud) بديل الـ AI تمامًا
    @GET("surah/{number}/ar.muyassar") suspend fun getSurahTafsir(@Path("number") number: Int): SurahDetailResponse
}

object ApiClient {
    private val moshi = Moshi.Builder().add(KotlinJsonAdapterFactory()).build()
    val aladhanApi: AladhanApi by lazy { Retrofit.Builder().baseUrl("https://api.aladhan.com/v1/").addConverterFactory(MoshiConverterFactory.create(moshi)).build().create(AladhanApi::class.java) }
    val alQuranApi: AlQuranApi by lazy { Retrofit.Builder().baseUrl("https://api.alquran.cloud/v1/").addConverterFactory(MoshiConverterFactory.create(moshi)).build().create(AlQuranApi::class.java) }
}

// --- قائمة الشيوخ (كلهم متاحين فعليًا في alquran.cloud) ---
data class Reciter(val edition: String, val name: String)

val RECITERS = listOf(
    Reciter("ar.alafasy", "مشاري العفاسي"),
    Reciter("ar.husary", "محمود خليل الحصري"),
    Reciter("ar.minshawi", "محمد صديق المنشاوي"),
    Reciter("ar.abdulbasitmurattal", "عبد الباسط عبد الصمد"),
    Reciter("ar.abdurrahmaansudais", "عبد الرحمن السديس"),
    Reciter("ar.saoodshuraym", "سعود الشريم"),
    Reciter("ar.mahermuaiqly", "ماهر المعيقلي"),
    Reciter("ar.muhammadayyoub", "محمد أيوب"),
    Reciter("ar.ahmedajamy", "أحمد بن علي العجمي"),
    Reciter("ar.hanirifai", "هاني الرفاعي")
)

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

// تفسير الميسر - نفس شكل بيانات السورة، بس النص هنا نص التفسير مش نص الآية
class TafsirViewModel : ViewModel() {
    var tafsir by mutableStateOf<SurahDetail?>(null)
        private set
    var isLoading by mutableStateOf(true)
        private set
    fun loadTafsir(number: Int) {
        isLoading = true
        viewModelScope.launch {
            try { tafsir = ApiClient.alQuranApi.getSurahTafsir(number).data } catch (e: Exception) { } finally { isLoading = false }
        }
    }
}

class AudioPlayerViewModel : ViewModel() {
    var selectedSurah by mutableStateOf<SurahDetail?>(null)
    var isPlaying by mutableStateOf(false)
    var currentAyahIndex by mutableStateOf(0)
    var isLoading by mutableStateOf(true)
    var selectedReciter by mutableStateOf(RECITERS.first())
        private set
    private var currentSurahNumber = 1
    private var mediaPlayer: MediaPlayer? = null

    init { loadSurahAudio(1) }

    private fun loadSurahAudio(number: Int) {
        currentSurahNumber = number
        isLoading = true
        stopAudio()
        viewModelScope.launch {
            try {
                selectedSurah = ApiClient.alQuranApi.getSurahAudio(number, selectedReciter.edition).data
                currentAyahIndex = 0
                playCurrentAyah()
            } catch (e: Exception) { } finally { isLoading = false }
        }
    }

    fun changeReciter(reciter: Reciter) {
        if (reciter.edition == selectedReciter.edition) return
        selectedReciter = reciter
        loadSurahAudio(currentSurahNumber)
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
                setOnErrorListener { _, _, _ -> this@AudioPlayerViewModel.isPlaying = false; true }
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

// --- محتوى ثابت رسمي (نصوص دينية كلاسيكية موثقة) بديل التوليد بالـ AI اللي كان بيفشل من غير مفتاح ---
data class DynamicItem(val text: String, val subtitle: String)

object IslamicContent {
    val ahadith = listOf(
        DynamicItem("إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى", "متفق عليه"),
        DynamicItem("من حسن إسلام المرء تركه ما لا يعنيه", "رواه الترمذي"),
        DynamicItem("لا يؤمن أحدكم حتى يحب لأخيه ما يحب لنفسه", "متفق عليه"),
        DynamicItem("الدين النصيحة", "رواه مسلم"),
        DynamicItem("من كان يؤمن بالله واليوم الآخر فليقل خيرًا أو ليصمت", "متفق عليه"),
        DynamicItem("المسلم من سلم المسلمون من لسانه ويده", "متفق عليه"),
        DynamicItem("الطُّهُورُ شَطْرُ الْإِيمَانِ", "رواه مسلم"),
        DynamicItem("بُنِيَ الْإِسْلَامُ عَلَى خَمْسٍ", "متفق عليه"),
        DynamicItem("خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ", "رواه البخاري"),
        DynamicItem("لَا ضَرَرَ وَلَا ضِرَارَ", "رواه ابن ماجه")
    )
    val adhkar = listOf(
        DynamicItem("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ", "تسبيح"),
        DynamicItem("أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ", "استغفار"),
        DynamicItem("لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ", "تهليل"),
        DynamicItem("اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكَ", "سيد الاستغفار"),
        DynamicItem("حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ", "أذكار الصباح والمساء"),
        DynamicItem("اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ", "دعاء جامع"),
        DynamicItem("رَضِيتُ بِاللَّهِ رَبًّا وَبِالْإِسْلَامِ دِينًا وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا", "أذكار الصباح"),
        DynamicItem("بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ", "أذكار المساء"),
        DynamicItem("اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ", "صلاة على النبي"),
        DynamicItem("سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ", "تسبيح")
    )
}

class DynamicListViewModel : ViewModel() {
    var items by mutableStateOf<List<DynamicItem>>(emptyList())
        private set
    var isLoading by mutableStateOf(true)
        private set

    fun loadContent(topic: String) {
        isLoading = true
        items = if (topic.contains("حديث")) IslamicContent.ahadith else IslamicContent.adhkar
        isLoading = false
    }
}
