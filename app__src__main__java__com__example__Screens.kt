package com.example

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import com.example.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuranListScreen(navController: NavHostController, viewModel: QuranViewModel = viewModel()) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("قراءة القرآن", fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = PrimaryDarkGreen, titleContentColor = Color.White, navigationIconContentColor = Color.White)
            )
        },
        containerColor = BackgroundCream
    ) { padding ->
        if (viewModel.isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = PrimaryDarkGreen) }
        } else {
            LazyColumn(contentPadding = padding, modifier = Modifier.fillMaxSize()) {
                items(viewModel.surahs) { surah ->
                    Card(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp).clickable { navController.navigate("surah/${surah.number}") },
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, CardBorderColor)
                    ) {
                        Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(40.dp).background(IconBackgroundLight, CircleShape), contentAlignment = Alignment.Center) {
                                Text("${surah.number}", color = TextTitleDark, fontWeight = FontWeight.Bold)
                            }
                            Spacer(Modifier.width(16.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(surah.name, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextTitleDark)
                                Text("${surah.revelationType} - ${surah.numberOfAyahs} آيات", fontSize = 14.sp, color = TextSubtitleGrey)
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SurahReadScreen(navController: NavHostController, surahNumber: Int, viewModel: SurahDetailViewModel = viewModel()) {
    LaunchedEffect(surahNumber) { viewModel.loadSurah(surahNumber) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(viewModel.surahDetail?.name ?: "جاري التحميل...", fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = PrimaryDarkGreen, titleContentColor = Color.White, navigationIconContentColor = Color.White)
            )
        },
        containerColor = BackgroundCream
    ) { padding ->
        if (viewModel.isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = PrimaryDarkGreen) }
        } else {
            LazyColumn(contentPadding = PaddingValues(16.dp), modifier = Modifier.fillMaxSize().padding(padding)) {
                val ayahs = viewModel.surahDetail?.ayahs ?: emptyList()
                item {
                    Text(
                        text = ayahs.joinToString(" ") { "${it.text} ﴿${it.numberInSurah}﴾" },
                        fontSize = 22.sp, lineHeight = 38.sp, color = TextTitleDark, textAlign = TextAlign.Justify, modifier = Modifier.fillMaxWidth().padding(8.dp)
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AudioPlayerScreen(navController: NavHostController, viewModel: AudioPlayerViewModel = viewModel()) {
    DisposableEffect(Unit) { onDispose { viewModel.stopAudio() } }
    var reciterMenuExpanded by remember { mutableStateOf(false) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("استماع القرآن", fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = PrimaryDarkGreen, titleContentColor = Color.White, navigationIconContentColor = Color.White)
            )
        },
        containerColor = BackgroundCream
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding), horizontalAlignment = Alignment.CenterHorizontally) {
            if (viewModel.isLoading) {
                Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = PrimaryDarkGreen) }
            } else {
                Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Box(modifier = Modifier.size(140.dp).background(IconBackgroundLight, CircleShape), contentAlignment = Alignment.Center) {
                            Icon(Icons.Filled.Headphones, contentDescription = null, modifier = Modifier.size(70.dp), tint = PrimaryDarkGreen)
                        }
                        Spacer(Modifier.height(20.dp))
                        Text(viewModel.selectedSurah?.name ?: "", fontSize = 26.sp, fontWeight = FontWeight.Bold, color = TextTitleDark)
                        Spacer(Modifier.height(6.dp))
                        Box {
                            Surface(shape = RoundedCornerShape(20.dp), color = Color.White, border = BorderStroke(1.dp, CardBorderColor), onClick = { reciterMenuExpanded = true }) {
                                Row(modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Filled.Person, contentDescription = "الشيخ", tint = TextSubtitleGrey, modifier = Modifier.size(16.dp))
                                    Spacer(Modifier.width(6.dp))
                                    Text(viewModel.selectedReciter.name, fontSize = 14.sp, color = TextSubtitleGrey, fontWeight = FontWeight.SemiBold)
                                    Spacer(Modifier.width(4.dp))
                                    Icon(Icons.Filled.ArrowDropDown, contentDescription = "اختيار الشيخ", tint = TextSubtitleGrey, modifier = Modifier.size(18.dp))
                                }
                            }
                            DropdownMenu(expanded = reciterMenuExpanded, onDismissRequest = { reciterMenuExpanded = false }) {
                                RECITERS.forEach { reciter ->
                                    DropdownMenuItem(
                                        text = { Text(reciter.name, fontWeight = if (reciter.edition == viewModel.selectedReciter.edition) FontWeight.Bold else FontWeight.Normal) },
                                        onClick = { viewModel.changeReciter(reciter); reciterMenuExpanded = false }
                                    )
                                }
                            }
                        }
                        Spacer(Modifier.height(28.dp))
                        Text(
                            text = viewModel.selectedSurah?.ayahs?.getOrNull(viewModel.currentAyahIndex)?.text ?: "",
                            fontSize = 22.sp, color = TextTitleDark, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 32.dp)
                        )
                        Spacer(Modifier.height(14.dp))
                        Text(
                            text = "الآية ${viewModel.currentAyahIndex + 1} من ${viewModel.selectedSurah?.ayahs?.size ?: 0}",
                            fontSize = 13.sp, color = TextSubtitleGrey
                        )
                    }
                }
                Surface(modifier = Modifier.fillMaxWidth().height(140.dp), color = Color.White, shape = RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp), shadowElevation = 16.dp) {
                    Row(modifier = Modifier.fillMaxSize(), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onClick = { viewModel.nextAyah() }) { Icon(Icons.Filled.SkipPrevious, contentDescription = "Next Ayah (RTL)", modifier = Modifier.size(44.dp), tint = PrimaryDarkGreen) }
                        Box(modifier = Modifier.size(84.dp).background(IconBackgroundLight, CircleShape), contentAlignment = Alignment.Center) {
                            IconButton(onClick = { viewModel.togglePlayPause() }) {
                                Icon(if (viewModel.isPlaying) Icons.Filled.PauseCircleFilled else Icons.Filled.PlayCircleFilled, contentDescription = "Play/Pause", modifier = Modifier.size(68.dp), tint = PrimaryDarkGreen)
                            }
                        }
                        IconButton(onClick = { viewModel.previousAyah() }) { Icon(Icons.Filled.SkipNext, contentDescription = "Prev Ayah (RTL)", modifier = Modifier.size(44.dp), tint = PrimaryDarkGreen) }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DynamicListScreen(navController: NavHostController, title: String, topic: String, viewModel: DynamicListViewModel = viewModel()) {
    LaunchedEffect(topic) { viewModel.loadContent(topic) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title, fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = PrimaryDarkGreen, titleContentColor = Color.White, navigationIconContentColor = Color.White)
            )
        },
        containerColor = BackgroundCream
    ) { padding ->
        if (viewModel.isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = PrimaryDarkGreen) }
        } else {
            LazyColumn(contentPadding = padding, modifier = Modifier.fillMaxSize()) {
                items(viewModel.items) { item ->
                    Card(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, CardBorderColor)
                    ) {
                        Column(modifier = Modifier.padding(16.dp).fillMaxWidth()) {
                            Text(text = item.text, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextTitleDark, textAlign = TextAlign.Right, modifier = Modifier.fillMaxWidth())
                            if (item.subtitle.isNotEmpty()) {
                                Spacer(Modifier.height(8.dp))
                                Text(text = item.subtitle, fontSize = 14.sp, color = TextSubtitleGrey, textAlign = TextAlign.Left, modifier = Modifier.fillMaxWidth())
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AlarmScreen(navController: NavHostController) {
    val prayers = listOf("الفجر" to "04:30", "الظهر" to "11:55", "العصر" to "15:20", "المغرب" to "18:05", "العشاء" to "19:30")
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("منبه الصلاة", fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = PrimaryDarkGreen, titleContentColor = Color.White, navigationIconContentColor = Color.White)
            )
        },
        containerColor = BackgroundCream
    ) { padding ->
        LazyColumn(contentPadding = padding, modifier = Modifier.fillMaxSize()) {
            items(prayers) { (name, time) ->
                var isChecked by remember { mutableStateOf(true) }
                Card(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    border = BorderStroke(1.dp, CardBorderColor)
                ) {
                    Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Switch(checked = isChecked, onCheckedChange = { isChecked = it }, colors = SwitchDefaults.colors(checkedThumbColor = PrimaryDarkGreen, checkedTrackColor = IconBackgroundLight))
                        Column(horizontalAlignment = Alignment.End) {
                            Text(text = name, fontWeight = FontWeight.Bold, fontSize = 18.sp, color = TextTitleDark)
                            Text(text = time, color = TextSubtitleGrey)
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TafsirSurahListScreen(navController: NavHostController, viewModel: QuranViewModel = viewModel()) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("تفسير القرآن (الميسر)", fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = PrimaryDarkGreen, titleContentColor = Color.White, navigationIconContentColor = Color.White)
            )
        },
        containerColor = BackgroundCream
    ) { padding ->
        if (viewModel.isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = PrimaryDarkGreen) }
        } else {
            LazyColumn(contentPadding = padding, modifier = Modifier.fillMaxSize()) {
                items(viewModel.surahs) { surah ->
                    Card(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp).clickable { navController.navigate("tafsir/${surah.number}") },
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, CardBorderColor)
                    ) {
                        Row(modifier = Modifier.padding(16.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(40.dp).background(IconBackgroundLight, CircleShape), contentAlignment = Alignment.Center) {
                                Text("${surah.number}", color = TextTitleDark, fontWeight = FontWeight.Bold)
                            }
                            Spacer(Modifier.width(16.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(surah.name, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextTitleDark)
                                Text("${surah.revelationType} - ${surah.numberOfAyahs} آيات", fontSize = 14.sp, color = TextSubtitleGrey)
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TafsirReadScreen(navController: NavHostController, surahNumber: Int, viewModel: TafsirViewModel = viewModel()) {
    LaunchedEffect(surahNumber) { viewModel.loadTafsir(surahNumber) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(viewModel.tafsir?.name ?: "جاري التحميل...", fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = { navController.popBackStack() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = PrimaryDarkGreen, titleContentColor = Color.White, navigationIconContentColor = Color.White)
            )
        },
        containerColor = BackgroundCream
    ) { padding ->
        if (viewModel.isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = PrimaryDarkGreen) }
        } else {
            val ayahs = viewModel.tafsir?.ayahs ?: emptyList()
            if (ayahs.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                    Text("تعذر تحميل التفسير، تأكد من اتصال الإنترنت", color = TextSubtitleGrey)
                }
            } else {
                LazyColumn(contentPadding = padding, modifier = Modifier.fillMaxSize()) {
                    items(ayahs) { ayah ->
                        Card(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
                            colors = CardDefaults.cardColors(containerColor = Color.White),
                            border = BorderStroke(1.dp, CardBorderColor)
                        ) {
                            Column(modifier = Modifier.padding(16.dp).fillMaxWidth()) {
                                Text("الآية ${ayah.numberInSurah}", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = PrimaryDarkGreen)
                                Spacer(Modifier.height(6.dp))
                                Text(ayah.text, fontSize = 17.sp, lineHeight = 28.sp, color = TextTitleDark, textAlign = TextAlign.Justify)
                            }
                        }
                    }
                }
            }
        }
    }
}
