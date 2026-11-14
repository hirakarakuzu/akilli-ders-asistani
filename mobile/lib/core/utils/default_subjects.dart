import 'package:shared_preferences/shared_preferences.dart';
import '../../db.dart';

/// Hazır ders listesi. Her kullanıcıya bir kez eklenir; var olan dersler tekrar eklenmez.
const defaultSubjects = [
  'Matematik',
  'Fizik',
  'Türkçe',
  'İngilizce',
  'Algoritma ve Programlama',
  'Veritabanı Sistemleri',
  'Web Programlama',
];

/// Sohbet ekranındaki ders bazlı hazır sorular.
const _subjectSuggestions = <String, List<String>>{
  'matematik': ['Türev nedir? Basitçe anlat.', 'Zincir kuralına örnek ver.', 'İntegral ile türev arasındaki ilişki ne?'],
  'fizik': ["Newton'un 2. yasasına örnek ver.", 'Sürtünme kuvveti nasıl hesaplanır?', 'İş ve enerji arasındaki fark ne?'],
  'türkçe': ['Cümlenin ögelerini örnekle anlat.', 'Belirtili ve belirtisiz nesne farkı ne?', 'Sözde özne nedir?'],
  'ingilizce': ['Present Perfect ile Past Simple farkı ne?', '"since" ve "for" ne zaman kullanılır?', 'Bana 5 cümlelik bir alıştırma ver.'],
  'algoritma ve programlama': ['Big-O gösterimini basitçe anlat.', 'İkili arama nasıl çalışır?', 'For ve while döngüsü farkı ne?'],
  'veritabanı sistemleri': ['JOIN türlerini örnekle anlat.', '3. normal form nedir?', 'Birincil ve yabancı anahtar farkı ne?'],
  'web programlama': ['CSS box model nedir?', 'Flexbox ile ortalama nasıl yapılır?', 'GET ve POST farkı ne?'],
};

const _generalSuggestions = [
  'Türev nedir? Basitçe anlat.',
  "Newton'un 2. yasasına örnek ver.",
  'SQL JOIN nedir?',
  'Sınava 2 haftam var, nasıl çalışmalıyım?',
];

List<String> suggestionsFor(String? subject) {
  final key = (subject ?? '').trim().toLowerCase();
  final list = _subjectSuggestions[key];
  if (list == null) return _generalSuggestions;
  return [...list, 'Bu dersten sınavda ne çıkar?'];
}

Future<void> ensureDefaultSubjects(int uid) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'default_subjects_v1_$uid';
  if (prefs.getBool(key) != true) {
    final existing = (await Repo.subjects(uid))
        .map((r) => ((r['name'] as String?) ?? '').trim().toLowerCase())
        .toSet();
    for (final s in defaultSubjects) {
      if (!existing.contains(s.toLowerCase())) {
        await Repo.addSubject(uid, s);
      }
    }
    await prefs.setBool(key, true);
  }
  await _ensureDefaultNotes(uid, prefs);
}

/// Hazır derslerden notu olmayanlara örnek bir ders notu ekler (bir kez).
Future<void> _ensureDefaultNotes(int uid, SharedPreferences prefs) async {
  final key = 'default_notes_v1_$uid';
  if (prefs.getBool(key) == true) return;
  final subjects = await Repo.subjects(uid);
  final notes = await Repo.notes(uid);
  final withNotes = notes.map((n) => n['subject_id']).toSet();
  for (final s in subjects) {
    final name = ((s['name'] as String?) ?? '').trim().toLowerCase();
    final note = defaultNotes[name];
    if (note == null || withNotes.contains(s['id'])) continue;
    await Repo.addNote(uid, s['id'] as int, note.$1, note.$2, logActivity: false);
  }
  await prefs.setBool(key, true);
}

/// ders adı (küçük harf) → (not başlığı, not içeriği)
const defaultNotes = <String, (String, String)>{
  'matematik': (
    'Türev – Temel Kavramlar ve Kurallar',
    r'''Türev, bir fonksiyonun bir noktadaki anlık değişim hızıdır. Geometrik olarak, fonksiyonun grafiğine o noktada çizilen teğet doğrusunun eğimidir.

Tanım: f'(a) = lim (h→0) [f(a+h) − f(a)] / h

Temel türev kuralları:
- Sabitin türevi sıfırdır: (c)' = 0
- Kuvvet kuralı: (xⁿ)' = n·xⁿ⁻¹  (örnek: (x³)' = 3x²)
- Sabitle çarpım: (c·f)' = c·f'
- Toplam/fark: (f ± g)' = f' ± g'
- Çarpım kuralı: (f·g)' = f'·g + f·g'
- Bölüm kuralı: (f/g)' = (f'·g − f·g') / g²
- Zincir kuralı: (f(g(x)))' = f'(g(x)) · g'(x)  (örnek: ((2x+1)⁵)' = 5(2x+1)⁴ · 2)

Önemli fonksiyonların türevleri:
- (sin x)' = cos x,  (cos x)' = −sin x
- (eˣ)' = eˣ,  (ln x)' = 1/x

Türevin uygulamaları:
- f'(x) > 0 olan aralıkta fonksiyon artan, f'(x) < 0 olan aralıkta azalandır.
- f'(x) = 0 olan noktalar yerel maksimum veya minimum adaylarıdır (kritik noktalar).
- İkinci türev f''(x) > 0 ise grafik yukarı bükey (çukur), f''(x) < 0 ise aşağı bükeydir.

Çözümlü örnek: f(x) = 3x² − 12x + 5
f'(x) = 6x − 12 → 6x − 12 = 0 → x = 2
f''(x) = 6 > 0 olduğundan x = 2'de yerel minimum vardır.
Minimum değer: f(2) = 12 − 24 + 5 = −7''',
  ),
  'fizik': (
    "Newton'un Hareket Yasaları",
    r'''1. Yasa (Eylemsizlik): Bir cisme etki eden net kuvvet sıfırsa cisim duruyorsa durmaya, hareket ediyorsa sabit hızla doğrusal hareketine devam eder.

2. Yasa (Temel yasa): Net kuvvet, kütle ile ivmenin çarpımına eşittir.
F_net = m · a
Kuvvetin birimi Newton'dur: 1 N = 1 kg·m/s². İvme her zaman net kuvvetle aynı yöndedir.

3. Yasa (Etki–Tepki): A cismi B'ye bir kuvvet uygularsa, B de A'ya aynı büyüklükte ve zıt yönde bir kuvvet uygular. Etki ve tepki farklı cisimlere etki ettiği için birbirini yok etmez.

İlgili kavramlar:
- Ağırlık: G = m · g  (g ≈ 9,8 m/s²)
- Normal kuvvet (N): Yüzeyin cisme dik olarak uyguladığı tepki kuvveti. Yatay düzlemde N = m·g.
- Sürtünme kuvveti: f = μ · N  (μ: sürtünme katsayısı). Harekete zıt yöndedir.

Çözümlü örnek 1: 2 kg'lık kutuya sürtünmesiz yatay zeminde 10 N yatay kuvvet uygulanıyor.
a = F/m = 10 / 2 = 5 m/s²

Çözümlü örnek 2: Aynı kutu için μ = 0,2 olsun.
N = 2 · 9,8 = 19,6 N
f = 0,2 · 19,6 = 3,92 N
F_net = 10 − 3,92 = 6,08 N
a = 6,08 / 2 = 3,04 m/s²

Sık yapılan hata: Kuvvetin yönü ile hızın yönünü karıştırmak. Kuvvet ivmeyi belirler, hızı değil.''',
  ),
  'türkçe': (
    'Cümlenin Ögeleri',
    r'''Cümlenin ögeleri bulunurken önce yüklem bulunur, diğer ögeler yükleme soru sorularak belirlenir.

1. Yüklem: Cümlede yargı bildiren ögedir; iş, oluş, hareket veya durum bildirir. Cümlenin temel ögesidir.

2. Özne: Yüklemin bildirdiği işi yapan ya da yargının kendisine bağlandığı ögedir. Yükleme "kim?" veya "ne?" sorusu sorularak bulunur.
- Gizli özne: Cümlede açıkça yazılmayan, yüklemin kişi ekinden anlaşılan öznedir. ("Okula gittim." → ben)
- Sözde özne: Edilgen fiillerde işi yapan belli değildir, işten etkilenen öge sözde öznedir. ("Kapı açıldı.")

3. Nesne: Yüklemin bildirdiği işten etkilenen ögedir.
- Belirtili nesne: "-ı/-i" hâl ekini alır, "kimi? neyi?" sorusunun cevabıdır. ("Kitabı okudum.")
- Belirtisiz nesne: Ek almaz, "ne?" sorusunun cevabıdır. ("Kitap okudum.")

4. Dolaylı tümleç (yer tamlayıcısı): "-e, -de, -den" hâl eklerini alır; "nereye? nerede? nereden? kime? kimde? kimden?" sorularının cevabıdır.

5. Zarf tümleci: İşin zamanını, biçimini, miktarını veya yönünü bildirir; "ne zaman? nasıl? ne kadar? niçin?" sorularının cevabıdır.

6. Edat tümleci: "ile, için, gibi, kadar" gibi edatlarla kurulan ögedir. ("Arkadaşıyla geldi.")

Çözümlü örnek: "Ali dün kütüphaneden iki kitap aldı."
- Yüklem: aldı
- Özne: Ali
- Belirtisiz nesne: iki kitap
- Dolaylı tümleç: kütüphaneden
- Zarf tümleci: dün''',
  ),
  'ingilizce': (
    'Present Perfect ve Past Simple',
    r'''Past Simple (Geçmiş Zaman)
Yapı: Özne + V2 (fiilin 2. hâli)  → I watched / She went
Olumsuz: did not + V1 → I didn't watch
Soru: Did + özne + V1? → Did you watch?
Kullanım: Geçmişte belirli bir zamanda başlayıp bitmiş eylemler.
Zaman ifadeleri: yesterday, last week, two days ago, in 2020, when I was a child
Örnek: I visited Ankara last year.

Present Perfect (Yakın Geçmiş / Süregelen)
Yapı: Özne + have/has + V3 (fiilin 3. hâli) → I have finished / She has seen
Olumsuz: have not / has not + V3 → I haven't finished
Soru: Have/Has + özne + V3? → Have you finished?
Kullanım:
- Zamanı belirtilmeyen geçmiş deneyimler: I have been to London.
- Etkisi şimdi süren eylemler: I have lost my keys. (Hâlâ bulamadım.)
- Geçmişte başlayıp hâlâ devam eden durumlar: She has lived here for five years.
Zaman ifadeleri: ever, never, already, yet, just, so far, recently, since, for

since ve for:
- since + başlangıç noktası: since 2019, since Monday
- for + süre: for three years, for two hours

En önemli fark: Belirli bir geçmiş zaman (yesterday, ago, last…) varsa Past Simple kullanılır; Present Perfect ile birlikte kullanılmaz.
Yanlış: I have seen him yesterday.
Doğru: I saw him yesterday.''',
  ),
  'algoritma ve programlama': (
    'Algoritma Temelleri ve Karmaşıklık',
    r'''Algoritma: Bir problemi çözmek için izlenen, sonlu sayıda, açık ve sıralı adımlar dizisidir.
Bir algoritmanın özellikleri: sonluluk (bir noktada biter), belirlilik (her adım açıktır), giriş, çıkış ve etkinlik.

Temel yapılar:
- Sıralı yapı: Komutlar yukarıdan aşağıya çalışır.
- Karar (koşul) yapısı: if / else ile koşula göre farklı yol izlenir.
- Döngü yapısı: for (tekrar sayısı belliyse), while (koşul sağlandıkça).

Örnek – Dizideki en büyük elemanı bulma:
enBuyuk = dizi[0]
her eleman x için:
    eğer x > enBuyuk ise enBuyuk = x
enBuyuk değerini döndür
Bu algoritma diziyi bir kez gezdiği için O(n) karmaşıklığa sahiptir.

Zaman karmaşıklığı (Big-O): Girdi büyüdükçe çalışma süresinin nasıl arttığını gösterir.
- O(1): Sabit – dizide indeksle elemana erişim
- O(log n): Logaritmik – sıralı dizide ikili arama
- O(n): Doğrusal – doğrusal arama, tek döngü
- O(n log n): Merge sort, (ortalama durumda) quick sort
- O(n²): İç içe iki döngü, bubble sort

İkili arama (binary search): Yalnızca sıralı dizide çalışır. Ortadaki elemana bakılır; aranan değer küçükse sol yarıda, büyükse sağ yarıda aramaya devam edilir. Her adımda arama alanı yarıya indiği için O(log n)'dir.

Özyineleme (recursion): Fonksiyonun kendini çağırmasıdır. Mutlaka bir durma (taban) koşulu olmalıdır, yoksa sonsuz döngüye girer.
Örnek: faktoriyel(n) = 1 (n ≤ 1 ise), aksi hâlde n · faktoriyel(n − 1)''',
  ),
  'veritabanı sistemleri': (
    'İlişkisel Veritabanı, SQL ve Normalizasyon',
    r'''İlişkisel model: Veriler satır (kayıt) ve sütunlardan (alan) oluşan tablolarda tutulur.
- Birincil anahtar (Primary Key): Her satırı benzersiz tanımlar, boş (NULL) olamaz.
- Yabancı anahtar (Foreign Key): Başka bir tablonun birincil anahtarına başvurur, tablolar arası ilişkiyi kurar.
İlişki türleri: bire-bir, bire-çok (bir müşterinin çok siparişi), çoka-çok (ara tablo ile kurulur).

Temel SQL komutları:
- SELECT ad, soyad FROM ogrenci WHERE bolum = 'YBS';
- INSERT INTO ogrenci (ad, soyad) VALUES ('Ayşe', 'Kaya');
- UPDATE ogrenci SET bolum = 'YBS' WHERE id = 5;
- DELETE FROM ogrenci WHERE id = 5;
- GROUP BY ile gruplama, COUNT / SUM / AVG gibi toplama fonksiyonları, HAVING ile grup filtresi, ORDER BY ile sıralama.

JOIN türleri:
- INNER JOIN: Yalnızca iki tabloda da eşleşen satırlar.
- LEFT JOIN: Sol tablonun tüm satırları, sağda eşleşme yoksa NULL.
- RIGHT JOIN: Sağ tablonun tüm satırları.
Örnek: SELECT o.ad, d.ders_adi FROM ogrenci o INNER JOIN kayit k ON k.ogrenci_id = o.id INNER JOIN ders d ON d.id = k.ders_id;

Normalizasyon: Veri tekrarını ve güncelleme anomalilerini azaltma sürecidir.
- 1NF: Her hücrede tek (atomik) değer olur, tekrar eden sütun grubu olmaz.
- 2NF: 1NF'dir ve anahtar olmayan her sütun birincil anahtarın tamamına bağlıdır (kısmi bağımlılık yoktur).
- 3NF: 2NF'dir ve anahtar olmayan sütunlar birbirine bağlı değildir (geçişli bağımlılık yoktur).

ACID (işlem özellikleri): Atomicity (bölünmezlik), Consistency (tutarlılık), Isolation (yalıtım), Durability (kalıcılık).''',
  ),
  'web programlama': (
    'HTML, CSS, JavaScript ve HTTP Temelleri',
    r'''HTML sayfanın yapısını, CSS görünümünü, JavaScript davranışını belirler.

HTML:
- Temel iskelet: <!DOCTYPE html>, <html>, <head>, <body>
- Semantik etiketler: <header>, <nav>, <main>, <section>, <article>, <footer>. Erişilebilirlik ve SEO için önemlidir.
- Form elemanları: <form>, <input>, <label>, <button>

CSS:
- Seçiciler: etiket (p), sınıf (.kart), kimlik (#menu). Öncelik sırası: kimlik > sınıf > etiket.
- Box model: Her eleman içten dışa content → padding → border → margin katmanlarından oluşur. box-sizing: border-box ile genişliğe padding ve border dahil edilir.
- Flexbox: display: flex; justify-content ana eksende, align-items çapraz eksende hizalar. Ortalamak için: justify-content: center; align-items: center;
- Responsive tasarım: @media (max-width: 768px) { ... } ile ekran boyutuna göre stil değiştirilir.

JavaScript:
- DOM: Sayfadaki elemanlara erişip değiştirme. document.querySelector('.kart')
- Olaylar: buton.addEventListener('click', () => { ... })
- Değişkenler: const (değişmez), let (değişebilir); var eski yöntemdir.
- Sunucudan veri alma: fetch('/api/dersler').then(r => r.json())

HTTP:
- Metotlar: GET (veri al), POST (veri gönder/oluştur), PUT (güncelle), DELETE (sil)
- Durum kodları: 200 OK, 201 Created, 400 Bad Request, 401 Unauthorized, 404 Not Found, 500 Internal Server Error
- GET parametreleri adres çubuğunda görünür; şifre gibi hassas veriler POST gövdesinde gönderilmelidir.''',
  ),
};
