package com.azkar.azkari_native;

/**
 * كلمات الأذان وتوقيتها مع الصوت.
 *
 * التوقيت أدناه مستخرج من الملف المدمج res/raw/adhan.mp3 (مدته 237.3 ثانية)
 * بكشف فترات الصمت بين العبارات (ffmpeg silencedetect). لو غيّرت الملف المدمج
 * عدّل المصفوفة START/END فقط. أما الأصوات المحمَّلة من الإنترنت فتُوزَّع عباراتها
 * بالنسبة والتناسب على مدة الملف (تقريبي).
 */
final class AdhanLyrics {
    private AdhanLyrics() {}

    /** عبارات الأذان بالترتيب (12 عبارة كما ينطقها المؤذن في الملف المدمج). */
    static final String[] LINES = {
            "اللهُ أكبرُ، اللهُ أكبرُ",
            "اللهُ أكبرُ، اللهُ أكبرُ",
            "أشهدُ أن لا إلهَ إلا اللهُ",
            "أشهدُ أن لا إلهَ إلا اللهُ",
            "أشهدُ أنَّ محمدًا رسولُ اللهِ",
            "أشهدُ أنَّ محمدًا رسولُ اللهِ",
            "حيَّ على الصلاةِ",
            "حيَّ على الصلاةِ",
            "حيَّ على الفلاحِ",
            "حيَّ على الفلاحِ",
            "اللهُ أكبرُ، اللهُ أكبرُ",
            "لا إلهَ إلا اللهُ",
    };

    /** بداية ونهاية كل عبارة بالملي ثانية في الملف المدمج. */
    private static final int[] START = {
            2430, 15070, 36680, 57510, 80680, 101300, 123420, 143690, 161580, 178770, 200340, 213430};
    private static final int[] END = {
            10290, 31440, 52380, 74190, 94850, 115640, 137180, 158360, 174760, 193600, 210330, 227600};
    private static final int BUNDLED_MS = 237336;

    /** الدعاء المأثور بعد الأذان (رواه البخاري) يظهر عند انتهاء الأذان. */
    static final String AFTER =
            "اللهمَّ ربَّ هذه الدعوةِ التامَّةِ، والصلاةِ القائمةِ، آتِ محمدًا الوسيلةَ والفضيلةَ، "
                    + "وابعثهُ مقامًا محمودًا الذي وعدتَه";

    /** حالة العرض: index = العبارة الحالية، progress 0..1 داخلها، done = انتهى الأذان. */
    static final class State {
        int index;
        float progress;
        boolean started, done;
    }

    private static int scale(int ms, int dur, boolean bundled) {
        if (bundled || dur <= 0) return ms;
        return Math.round(ms * (dur / (float) BUNDLED_MS));
    }

    static State at(int posMs, int durMs, boolean bundled) {
        State s = new State();
        int n = LINES.length;
        int firstStart = scale(START[0], durMs, bundled);
        int lastEnd = scale(END[n - 1], durMs, bundled);
        if (posMs < firstStart) {
            s.index = 0;
            return s;
        }
        s.started = true;
        if (posMs >= lastEnd) {
            s.index = n - 1;
            s.progress = 1f;
            s.done = true;
            return s;
        }
        for (int i = 0; i < n; i++) {
            int a = scale(START[i], durMs, bundled), b = scale(END[i], durMs, bundled);
            int nextA = i + 1 < n ? scale(START[i + 1], durMs, bundled) : b;
            if (posMs < nextA) {
                s.index = i;
                s.progress = posMs <= a ? 0f : Math.min(1f, (posMs - a) / (float) Math.max(1, b - a));
                return s;
            }
        }
        s.index = n - 1;
        return s;
    }
}
