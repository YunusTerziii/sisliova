# Karaçam test raporu

Tarih: 27 Ekim 2026 · İçerik sürümü `1.0.0-alpha.1` · Kayıt şeması 1

Bu rapor neyin **gerçekten çalıştırıldığını** ve neyin **hâlâ açık** olduğunu ayırır. Bu ortamda Xcode ve iOS SDK
yoktur; iOS derlemesi, simülatör, cihaz, satın alma veya insan testi yapılmış gibi sunulmaz.

## 1. Gerçekten çalıştırılanlar

Ortam: Linux konteyner, Docker `swift:6.1-noble`, `Swift version 6.1.3 (swift-6.1.3-RELEASE)`, Swift 6 dil modu.

| Ne | Komut | Sonuç |
|---|---|---|
| Çekirdek + uygulama modeli testleri | `swift test` | **53/53 geçti** (swift-testing) |
| Denge simülasyonu | `swift run -c release karacam-sim 40` | 1.440 tam oyun, **0 takılma** |
| SwiftUI kaynakları sözdizimi | `swiftc -parse App/**/*.swift` | Geçti (yalnız sözdizimi; tip denetimi değil) |
| StoreKit yapılandırması, `project.yml` | JSON/YAML ayrıştırma | Geçti |

### Test grupları

- **İçerik (5)**: 30 günlük katalog ve beş bölüm çözülüyor; her sahne/gündem/son/epilog referansı var olan bir
  hedefe gidiyor; her yuva sahnesinin ücretsiz bir yolu var (iki bilinçli istisna: 1. gün işletme seçimi,
  30. gece final); bilinmeyen tür yok ve paralar kuruş; Derya seçimleri yalnız bayrak koyuyor.
- **Ekonomi (9)**: güven çarpanı (%70/%100/%125) sınırları, baskı kesintisi (49→0, 50→100 TL, 80→3.000 TL tavan),
  baskı 100'de erken tahsilat, aidat 14. akşam var 15. akşam yok, aynı akşam ve aynı komut iki kez işlenmiyor,
  köprü onarımı bugün öder yarın ödemez, kaplıca kapanınca ilgili bütün gelir/gider kapanıyor ama ortak tezgâh kalıyor,
  yarım gün yalnız 29. akşamı etkiliyor, para biçimi.
- **Akış (13)**: ücretsiz bölüm kapısı 8. günü kilitliyor; gündem 9. gün açılıyor ve sabah bir kez harcanıyor;
  alınmayan sipariş 16. gün olmayan taahhüdü çağırmıyor; hazırlık parası yetmese de ortak ve iptal yolu var;
  teslimat net 8.000 TL'yi bir kez veriyor; en fazla iki açık taahhüt; ortak kurul yalnız yeni projeleri bir gün
  geciktiriyor, merkezi yetki aynı gün başlatıyor; şikâyet düşük güven + bilinen aksama istiyor, korumalı günleri
  atlıyor, son günlere oylama düşürmüyor; günün başına dönüş revision'ı ileri taşıyor, tohumu değiştirmiyor;
  ilk tahmin geri sarmadan sağ çıkıyor.
- **Vaka (9)**: tek iddia kimseyi elemiyor; üç bağımsız kayıt kanıtlıyor, kopyalar kanıtlamıyor; iz netliği suçludan
  bağımsız; tohum vakayı sabitliyor; spec'teki erken yol (9 imza → 10 tarih → 11 görüşme → 12 mühür → 13 dosya)
  13. günde kapanıyor ve 18. gün dosya toplantısını, 21. gece seçimini değiştiriyor; 10. gece hedefli soru konumu
  bir kez veriyor; yanlış itham güveni bir kez düşürüyor ve düzeltilebiliyor; yanlış ilk tahmin dosyayı kilitlemiyor;
  sunum katmanı kanıt yokken suçluyu sızdırmıyor.
- **Uçtan uca (5)**: 6 strateji × 3 vaka × 2 işletme × 4 tohum her oyun bir sona ulaşıyor; ödeme tek kez düşülüyor;
  7. gün satış hemen bitiriyor ve satış epilogunu veriyor; biten oyunda akşam/gün sonu reddediliyor;
  son ve epilog metinlerinde doldurulmamış `{yer tutucu}` kalmıyor.
- **Kayıt (6)**: gidiş-dönüş; bozuk ana dosyada yedekten açılış; yeni oyundan sonra eski oyunun geç yazısı
  reddediliyor; eski revision yeninin üstüne yazılmıyor; şema 0 → 1 göçü ilk tahmini koruyor; bilinmeyen şema
  reddediliyor ama dosya silinmiyor.
- **GameStore (6)**: boş isim düşüyor; eski ekrandan gelen ikinci dokunuş işlenmiyor; kayıt yazılamazsa eski durum
  korunuyor ve aynı komut sonra başarıyla işleniyor; kilitli kapı ilerlemeden satın alma ekranı istiyor, hak gelince
  8. güne geçiyor; geri bildirim yalnız kayıt başarılıysa çalıyor; yeniden açılışta devam satırı görünüyor.

### Kalite kapıları (spec §15)

| Kapı | Karşılayan test |
|---|---|
| Aynı komut/akşam ikinci kez para üretmez | `sameEveningAndCommandAreNotProcessedTwice`, `staleScreenTapIsIgnored` |
| Aidat son gün dahil doğru biter | `duesPresentOnEvening14AbsentOn15` |
| Kaplıca kapanınca bütün ilgili gelir/gider kapanır | `closingSpaClosesItsLinesButKeepsCommonStall` |
| Sipariş alınmadıysa olmayan taahhüt çağrılmaz | `orderNotTakenBringsFallbackOnSixteen` |
| Hazırlık nakdi net kârla karışmaz | `deliveryNetsEightThousandOnce` |
| Aynı kapasite tekrar satılamaz | `atMostTwoOpenCommitments` (kısmen; ayrı kapasite testi yok) |
| Yanlış ilk tahmin dosyayı kilitlemez | `wrongFirstGuessDoesNotLockTheFile` |
| Erken çözülen dosya tekrar açılmaz | `earlyPathResolvesByDayThirteen` |
| Romantizmi istememek ana oyunu bozmaz | `deryaChoicesOnlySetFlags` + uçtan uca stratejiler Derya'sız da sona ulaşıyor |
| Son gün geliri bir kez, taksit bir kez | `finalDayPaysOnceAndCannotBeReplayed`, `everyStrategyAndCaseReachesAnEnding` |
| Son üç gün gizli kesinti yok | `complaintAvoidsProtectedAndLastDays` |
| Her son için ne/neden/hangi karar | `everyEndingHasExplanationAndEpilogue`, `endingPresentationFillsAllPlaceholders` |

## 2. Denge bulguları (otomatik oyuncu, 40 tohum/hücre)

Otomatik oyuncu belirlenmiş stratejilerle oynar; insan davranışının tek modeli değildir. Tohum yalnız vakayı ve
iz netliğini değiştirdiği için "rastgele" dışındaki stratejiler tohumlar arasında aynı sonucu verir.

| Strateji | Kaplıca: son · ödeme öncesi kasa · güven 60 günü | Arı evi: son · kasa · güven 60 günü |
|---|---|---|
| dengeli | Birlikte kurtardık · 227–230 bin · 10. gün | Birlikte kurtardık · 226 bin · 7. gün |
| yardımsever | Birlikte kurtardık · 187–188 bin · 5–6. gün | Birlikte kurtardık · 167 bin · 5. gün |
| araştırmacı | Birlikte kurtardık · 189–197 bin · 11–15. gün | Birlikte kurtardık · 185–187 bin · 9–10. gün |
| tüccar | Köy desteği kaybı · 189 bin · hiç | Köy desteği kaybı · 229 bin · hiç |
| riskçi | Destek kaybı (Selim/Sevim), erken tahsilat (Halil) | Köy desteği kaybı · 182–192 bin |
| rastgele | 31 köy nefes aldı, 46 birlikte, 4 kasa, 39 destek kaybı | 35 köy nefes aldı, 57 birlikte, 0 kasa, 28 destek kaybı |

Toplam 1.440 oyun: birlikte kurtardık 823, köy nefes aldı 66, köy desteği kaybı 507, erken tahsilat 40, kasa 4,
satış 0 (stratejiler satışı kabul etmiyor; satış yolu ayrı testle doğrulandı).

**Raporlanması istenen noktalar:**

1. **Güven hızlı doluyor.** Yardımsever oyuncu 5. gün 60'a ulaşıyor; dengeli oyuncu arı evinde 7., kaplıcada 10. gün.
   Bu, %125 çarpanının oyunun büyük kısmında açık olması demek.
2. **Kasa sonu çok seyrek.** Para odaklı olmayan stratejiler bile ödemeden önce 167–230 bin TL'ye ulaşıyor
   (taksit 150 bin). Gerilim oyun ortasında: en düşük kasa 2.700–4.600 TL'ye kadar iniyor. Para kaybı ancak
   rastgele oyunda ve çok nadiren (4/240) görülüyor.
3. **İşletme farkı stratejiye bağlı.** Dengeli oyunda iki işletme neredeyse eşit; yardımsever oyunda arı evi ~20 bin
   geride; tüccar oyunda arı evi ~40 bin önde.
4. **Asıl kayıp yolu güven.** Tüccar ve riskçi oyuncular parayı bulup köyü kaybediyor; bu tasarımın istediği
   "para yetti ama destek yok" sonudur.

**Değiştirilen denge değeri yok.** Spec'teki alfa değerleri (`balance.json`) aynen duruyor. Yukarıdaki bulgular insan
testinden önce sayıları değiştirmek için yeterli görülmedi. İnsan testi aynı yönü gösterirse ilk adaylar:
yüksek güven çarpanını %115'e indirmek, ya da 9–14. günlerdeki güven ödüllerini 1 puan düşürmek; kasa gerilimi
için 22–27. gün gider kalemlerini artırmak. Her değişiklik `karacam-sim` ile yeniden ölçülmeli.

## 3. Açık olanlar (yapılmadı / yapılamadı)

| Konu | Durum |
|---|---|
| iOS derlemesi | **Yapılmadı.** Bu ortamda Xcode/iOS SDK yok. SwiftUI dosyaları yalnız sözdizimi denetiminden geçti; tip denetimi ilk Xcode derlemesinde yapılacak, küçük derleme hataları beklenmeli. |
| Xcode projesi | `project.yml` hazır; `Karacam.xcodeproj` üretilmedi (XcodeGen bu ortamda kurulamadı). Mac'te `xcodegen generate`. |
| Simülatör / cihaz testi | Yapılmadı. Dynamic Type (en büyük boyutlar), VoiceOver, 44 pt hedefler, küçük ekran (iPhone SE) gerçek cihazda denenmeli. |
| StoreKit | Kod ve yerel `Karacam.storekit` hazır; **hiç çalıştırılmadı.** Başarılı, iptal, bekleyen (Ask to Buy), hata, iade ve geri yükleme Xcode StoreKit test ortamında denenmeli. App Store Connect'te ürün tanımlı değil; yerel yapılandırmadaki fiyat (149,99) yer tutucudur. |
| İmza / ekip | `DEVELOPMENT_TEAM` boş; bundle kimliği `com.yunusterzi.karacam` önerisidir. |
| İnsan testi | Yapılmadı. Spec'teki 3–5 kişilik sesli düşünme testi ve gerçek oyun süresi (hedef 60–90 dk) ölçümü açık. |
| Derya portresi | Yok. Derya sahnelerinde kaplıca çizimi gösteriliyor. Üretim komutu: [derya-gorsel-komutu.md](derya-gorsel-komutu.md). |
| Ara görseller | Nermin (159×300), araba ve kamyon (~300 px) web demosundan; 1024 px yeniden üretilmeli. |
| Uygulama simgesi | Geçici: haritadan kare kırpım. Küçük boyutta fazla ayrıntılı; ayrı bir simge çizimi gerekli. |
| Ses | Ses dosyası yok; ses tercihi saklanıyor ama çalınacak efekt yok. Haptic var. |
| Harita durum katmanları | Ayrı katman görselleri yok; köprü/kaplıca/arı evi/tezgâh durumu SwiftUI işaretleri ve metinle gösteriliyor. |
| Yayın | App Store'a gönderilmedi; dışarıya mesaj gönderilmedi. |

## 4. Mac'te ilk oturum için sıra

1. `cd karacam && swift test` (53 testin Mac'te de geçtiğini doğrula).
2. `xcodegen generate`, Xcode'da ekibi seç, iPhone simülatöründe derle; çıkan tip hatalarını düzelt.
3. 1–7. günü oyna, 7. akşam satın alma ekranını StoreKit test ortamında dene (başarılı / iptal / bekleyen / hata).
4. Ayarlar → Erişilebilirlik → en büyük yazı boyutuyla Masa ve Defter'i kontrol et; VoiceOver ile Kasaba haritası.
5. Bir tam oyunu baştan sona oyna; süreyi not et. Sonra 3–5 kişilik sesli düşünme testi.
