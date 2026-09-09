package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.example.ui.theme.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MyApplicationTheme {
                AppNavigation()
            }
        }
    }
}

@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = "dashboard") {
        composable("dashboard") { DashboardScreen(navController) }
        composable("tafseer") { TafsirSurahListScreen(navController) }
        composable("tafsir/{number}", arguments = listOf(navArgument("number") { type = NavType.IntType })) { backStackEntry ->
            TafsirReadScreen(navController, backStackEntry.arguments?.getInt("number") ?: 1)
        }
        composable("alarm") { AlarmScreen(navController) }
        composable("quran") { QuranListScreen(navController) }
        composable("surah/{number}", arguments = listOf(navArgument("number") { type = NavType.IntType })) { backStackEntry ->
            SurahReadScreen(navController, backStackEntry.arguments?.getInt("number") ?: 1)
        }
        composable("ahadith") { DynamicListScreen(navController, "أحاديث الرسول", "أحاديث نبوية صحيحة") }
        composable("adhkar") { DynamicListScreen(navController, "أدعية", "أذكار وأدعية إسلامية") }
        composable("listen") { AudioPlayerScreen(navController) }
    }
}

@Composable
fun DashboardScreen(navController: NavHostController, viewModel: MainViewModel = viewModel()) {
    Scaffold(
        topBar = { TopBar(text = viewModel.topBarText) },
        bottomBar = { BottomNavBar() },
        containerColor = BackgroundCream
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding).fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item { HeroCard(onClick = { navController.navigate("listen") }) }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    SmallCard("قراءة القرآن", "منه ورده", Icons.AutoMirrored.Filled.MenuBook, { navController.navigate("quran") }, Modifier.weight(1f))
                    SmallCard("منبه صلاة", "نشط", Icons.Filled.NotificationsActive, { navController.navigate("alarm") }, Modifier.weight(1f))
                }
            }
            item { FullWidthCardTafseer({ navController.navigate("tafseer") }, { navController.navigate("tafseer") }) }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    SmallCard("أدعية", "", Icons.Filled.Edit, { navController.navigate("adhkar") }, Modifier.weight(1f))
                    SmallCard("أحاديث الرسول", "منه ورده", Icons.Filled.Nightlight, { navController.navigate("ahadith") }, Modifier.weight(1.4f))
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.height(IntrinsicSize.Min)) {
                    SmallCard("التاريخ الهجري", viewModel.hijriDateText, Icons.Filled.Sensors, { }, Modifier.weight(1f).fillMaxHeight())
                    SmallCard("التشغيل", "", Icons.Filled.PlayArrow, { navController.navigate("listen") }, Modifier.weight(1f).fillMaxHeight())
                }
            }
            item { FullWidthCardListen { navController.navigate("listen") } }
        }
    }
}

// Components remain identical to perfectly match UI
@Composable
fun TopBar(text: String) {
    Surface(modifier = Modifier.fillMaxWidth().statusBarsPadding(), color = PrimaryDarkGreen) {
        Row(modifier = Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Outlined.Settings, contentDescription = "Settings", tint = Color.White, modifier = Modifier.size(28.dp))
            Text(text = text, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            Icon(Icons.Filled.EventNote, contentDescription = "Calendar", tint = Color.White, modifier = Modifier.size(28.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HeroCard(onClick: () -> Unit) {
    Surface(modifier = Modifier.fillMaxWidth().height(140.dp), shape = RoundedCornerShape(16.dp), color = Color.White, border = BorderStroke(1.dp, CardBorderColor), onClick = onClick) {
        Box(modifier = Modifier.fillMaxSize()) {
            Icon(Icons.AutoMirrored.Filled.VolumeUp, contentDescription = "Volume", tint = TextTitleDark, modifier = Modifier.align(Alignment.CenterStart).padding(start = 24.dp).size(32.dp))
            Text(text = "تلاوات القرآن صوت", fontWeight = FontWeight.Bold, fontSize = 24.sp, color = TextTitleDark, modifier = Modifier.align(Alignment.CenterStart).padding(start = 72.dp))
            Icon(imageVector = Icons.Filled.Mosque, contentDescription = null, modifier = Modifier.align(Alignment.BottomEnd).padding(end = 16.dp).offset(y = 16.dp).size(120.dp), tint = MosqueTint)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SmallCard(title: String, sub: String, icon: ImageVector, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Surface(modifier = modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp), color = Color.White, border = BorderStroke(1.dp, CardBorderColor), onClick = onClick) {
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = Modifier.size(48.dp).background(IconBackgroundLight, CircleShape), contentAlignment = Alignment.Center) {
                Icon(icon, contentDescription = title, tint = TextTitleDark, modifier = Modifier.size(24.dp))
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.End) {
                Text(text = title, color = TextTitleDark, fontWeight = FontWeight.Bold, fontSize = 16.sp, textAlign = TextAlign.Right)
                if (sub.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(text = sub, color = TextSubtitleGrey, fontSize = 12.sp, textAlign = TextAlign.Right, maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FullWidthCardTafseer(onCardClick: () -> Unit, onAiClick: () -> Unit) {
    Surface(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp), color = Color.White, border = BorderStroke(1.dp, CardBorderColor), onClick = onCardClick) {
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = Modifier.size(48.dp).background(IconBackgroundLight, CircleShape), contentAlignment = Alignment.Center) {
                Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = "Tafseer", tint = TextTitleDark, modifier = Modifier.size(24.dp))
            }
            Spacer(modifier = Modifier.width(16.dp))
            Text("تفسير القرآن", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = TextTitleDark, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
            Spacer(modifier = Modifier.width(16.dp))
            OutlinedButton(onClick = onAiClick, shape = RoundedCornerShape(8.dp), border = BorderStroke(1.dp, CardBorderColor), colors = ButtonDefaults.outlinedButtonColors(contentColor = TextTitleDark), contentPadding = PaddingValues(horizontal = 16.dp, vertical = 0.dp), modifier = Modifier.height(36.dp)) {
                Text("رسمي", fontWeight = FontWeight.Bold, fontSize = 14.sp)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FullWidthCardListen(onClick: () -> Unit) {
    Surface(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp), color = Color.White, border = BorderStroke(1.dp, CardBorderColor), onClick = onClick) {
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = Modifier.size(48.dp).background(IconBackgroundLight, CircleShape), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Headphones, contentDescription = "Listen", tint = TextTitleDark, modifier = Modifier.size(24.dp))
            }
            Spacer(modifier = Modifier.width(16.dp))
            Text("استماع القرآن", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = TextTitleDark, modifier = Modifier.weight(1f), textAlign = TextAlign.End)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActionOutlineButton(text: String, icon: ImageVector, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Surface(modifier = modifier.height(48.dp), shape = RoundedCornerShape(12.dp), color = Color.Transparent, border = BorderStroke(1.dp, CardBorderColor), onClick = onClick) {
        Row(modifier = Modifier.fillMaxSize().padding(horizontal = 4.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = text, tint = TextTitleDark, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text(text, color = TextTitleDark, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
fun BottomNavBar() {
    NavigationBar(containerColor = Color.White, contentColor = TextSubtitleGrey, tonalElevation = 8.dp) {
        NavigationBarItem(icon = { Icon(Icons.Filled.Home, contentDescription = "Home") }, label = { Text("الرئيسية") }, selected = true, onClick = { }, colors = NavigationBarItemDefaults.colors(selectedIconColor = PrimaryDarkGreen, selectedTextColor = PrimaryDarkGreen, indicatorColor = IconBackgroundLight))
        NavigationBarItem(icon = { Icon(Icons.Outlined.Explore, contentDescription = "Explore") }, label = { Text("استكشف") }, selected = false, onClick = { })
    }
}
