# Karaçam — Kasabayı Kurtar (iPhone)

30 oyun günü süren, Türkçe, tek oyunculu bir karar ve gizem oyunu. iOS 17+, SwiftUI, Swift 6 dil modu.
İlk bölüm (1–7. gün) ücretsiz; kalan oyun tek bir non-consumable satın almayla açılır.

Ayrıntılı durum ve neyin gerçekten çalıştırıldığı: [docs/test-raporu.md](docs/test-raporu.md).

## Yapı

```
karacam/
├── Package.swift                  SwiftPM: çekirdek, uygulama modeli, simülatör, testler
├── Sources/KaracamCore/           Saf Foundation oyun çekirdeği (SwiftUI/StoreKit/ağ yok)
│   ├── Engine.swift               reducer: komut + revision → yeni snapshot
│   ├── Effects.swift, Rulebook.swift  etki ve koşul yorumlayıcıları
│   ├── Economy.swift              akşam hesabı (Int64 kuruş), baskı kesintisi, projeksiyon, vaka çözücü
│   ├── Cases.swift, Social.swift  kanıt/itham/düzeltme; şikâyet, oylama, final
│   ├── Presentation.swift         görünüme yalnız izinli bilgi aktaran sunum katmanı
│   ├── SaveRepository.swift       atomik kayıt aktörü, yedek, şema göçü
│   ├── Autoplay.swift             strateji tabanlı otomatik oyuncu (denge ve uçtan uca testler)
│   └── Resources/Content/         kanonik JSON içerik paketi
├── Sources/KaracamAppModel/       @MainActor @Observable GameStore, tercihler (Linux'ta da test edilir)
├── Sources/karacam-sim/           denge simülatörü: `swift run -c release karacam-sim 40`
├── Tests/                         swift-testing testleri
├── App/Karacam/                   SwiftUI uygulaması, StoreKit 2, varlık kataloğu
├── App/Karacam.storekit           yerel StoreKit test yapılandırması (gerçek ürün değil)
└── project.yml                    XcodeGen tanımı
```

## İçerik paketi

`Sources/KaracamCore/Resources/Content/`: `balance.json`, `calendar.json`, `story.json` (102 sahne),
`activities.json` (gündem), `cases.json` (üç vaka), `endings.json` (altı son), `epilogues.json`,
`social_rules.json`, `sale_terms.json`, `asset_manifest.json`. Bilinmeyen etki veya koşul türü yükleme
sırasında hata verir; para değerleri kuruş cinsinden tam sayıdır.

## Mac'te çalıştırma

1. Xcode 16 veya üstü (Swift 6). Sürümü `xcodebuild -version` ile doğrula.
2. Çekirdek testleri: `cd karacam && swift test`
3. Xcode projesini üret: `brew install xcodegen && xcodegen generate` → `Karacam.xcodeproj`
4. Projede **Signing & Capabilities** altında kendi ekibini seç (`DEVELOPMENT_TEAM` boş bırakıldı).
   Gerekirse `PRODUCT_BUNDLE_IDENTIFIER` (`com.yunusterzi.karacam`) ve ürün kimliğini
   (`com.yunusterzi.karacam.tamoyun`, `EntitlementStore.productID`) App Store Connect'tekiyle eşleştir.
5. Karacam şemasıyla simülatörde çalıştır. Şema yerel StoreKit yapılandırmasını kullanır; satın alma
   akışı (başarılı, iptal, bekleyen, hata) Xcode'un **Debug → StoreKit → Manage Transactions** ekranından denenebilir.

## Denge simülatörü

```
swift run -c release karacam-sim 40
```

Altı strateji (dengeli, tüccar, yardımsever, araştırmacı, riskçi, rastgele) × iki işletme × üç vaka ×
tohum. Son dağılımı, ödeme öncesi ortalama kasa, en düşük kasa, çözülen dosya sayısı, güvenin 60'a ulaştığı
ortalama gün ve takılan oyunları yazar.
