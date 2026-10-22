# Sisliova Karar Masası

"30 Günde Kasabayı Kurtar" serisinin Instagram bio linki için tek sayfalık site: kasabanın güncel sayaçları, açık oylama, verilen kararların arşivi ve oyun bekleme listesi.

Yayın: GitHub Pages, `main` dalının kökü. Adres: https://kasabayikurtar.com (DNS: Namecheap, 4 GitHub Pages A kaydı + www CNAME)

## Her bölümden sonra güncelleme

Yalnızca `index.html` içindeki `SEZON` bloğu değişir:

- `durum`: o günün gün / kasa / borç / güven değerleri (`sisliova-shorts/docs/continuity.csv` ile aynı olmalı).
- `bolumler`: yeni bölüm satırı eklenir; oylama kapanınca `kazanan` ve `sonuc` doldurulur. `kazanan: null` olan bölüm "oylama açık" kartında görünür.
- `link`: bölümün Instagram linki. Boş bırakılırsa ilgili buton gizlenir veya `instagram` profil linkine düşer.

Kurgusal animasyon serisi. Görseller dizinin kendi çizimleridir.
