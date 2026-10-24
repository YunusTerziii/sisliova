// Kullanım: node --stack-size=8000 araclar/denge-simulasyonu.js
// Oyunun gerçek motor bölümünü (MOTOR BAŞI..MOTOR SONU) yükleyip bütün yolları gezer.
// Oranlar ağırlıklıdır: her ikili seçimde iki seçenek %50, tek seçenekli kartta %100, hain üçte bir.
const fs = require('fs');
const src = fs.readFileSync(process.argv[2] || require('path').join(__dirname, '../oyun/index.html'), 'utf8');
const motor = src.slice(src.indexOf('// ===== MOTOR BAŞI'), src.indexOf('// ===== MOTOR SONU'));
const M = new Function(motor + '; return { siradakiKart, cozSecim, uygula, ilerle, aksamHesapla, aksamDokum, sinirKontrol, cozuldu, adaylar, yeniDurum, kopruTamir, kopruTamirEdilebilir, SUPHELILER };')();
const klon = o => JSON.parse(JSON.stringify(o));

// secici(kartId, secenekler, o) -> [[indeks, olasılık], ...]; akşam köprü tamiri "aksam-kopru" kararıdır (0 = tamir)
function gez(o, p, secici, cik) {
  const kart = M.siradakiKart(o);
  const sec = [kart.a, kart.b].filter(Boolean).map(s => M.cozSecim(kart, s, o));
  for (const [i, pi] of secici(kart.id, sec, o)) {
    const e = klon(o);
    M.uygula(sec[i], e);
    if (sec[i].son) { cik(sec[i].son, e, p * pi); continue; }
    let s = M.sinirKontrol(e); if (s) { cik(s, e, p * pi); continue; }
    if (M.ilerle(e) === 'aksam') {
      M.aksamHesapla(e);
      s = M.sinirKontrol(e); if (s) { cik(s, e, p * pi); continue; }
      if (M.kopruTamirEdilebilir(e)) {
        for (const [j, pj] of secici('aksam-kopru', [{}, {}], e)) {
          const f = klon(e); if (j === 0) M.kopruTamir(f);
          gez(f, p * pi * pj, secici, cik);
        }
        continue;
      }
    }
    gez(e, p * pi, secici, cik);
  }
}
const kayit = e => {
  const net = M.aksamDokum(e).net;
  return { kasa: e.kasa, guven: e.guven, suphe: e.suphe, net, otuz: e.kasa + net * (30 - e.gun),
    is: e.bayraklar.kaplica ? (e.bayraklar.kaplicaSatildi ? 'kaplıca (satıldı)' : 'kaplıca') : 'arı evi',
    nakliye: e.gelirler.some(g => g.kaynak === 'kopru'), coz: M.cozuldu(e), aday: M.adaylar(e).length };
};
const pct = x => (x * 100).toFixed(1) + '%';
const tl = n => Math.round(n).toLocaleString('tr-TR');

function analiz(baslik, secici) {
  let yaprak = 0; const son = {}; const D = [];
  for (const h of M.SUPHELILER) gez(M.yeniDurum('', h), 1 / 3, secici, (s, e, p) => {
    yaprak++; son[s] = (son[s] || 0) + p;
    if (s === 'demo') D.push(Object.assign(kayit(e), { p }));
  });
  const PD = D.reduce((t, x) => t + x.p, 0);
  const ort = (f, L = D) => L.reduce((t, x) => t + x.p * f(x), 0) / L.reduce((t, x) => t + x.p, 0);
  const oran = (f, L = D) => L.filter(f).reduce((t, x) => t + x.p, 0) / L.reduce((t, x) => t + x.p, 0);
  const dilim = (f, q) => { const s = D.map(x => [f(x), x.p]).sort((a, b) => a[0] - b[0]); let c = 0; for (const [v, p] of s) { c += p; if (c >= q * PD) return v; } };
  console.log('\n## ' + baslik + '  (' + yaprak + ' yaprak, oranlar ağırlıklı)');
  console.log('Sonuçlar: ' + Object.entries(son).map(([k, v]) => k + ' ' + pct(v)).join(', '));
  console.log('7. günü bitirenler: kasa ort ₺' + tl(ort(x => x.kasa)) + ' (alt %10 ₺' + tl(dilim(x => x.kasa, .1)) + ', üst %10 ₺' + tl(dilim(x => x.kasa, .9)) + '), güven ort ' + ort(x => x.guven).toFixed(1) + ', baskı≥50 ' + pct(oran(x => x.suphe >= 50)));
  console.log('  her akşam net ort ₺' + tl(ort(x => x.net)) + ', bu hızla 30. gün kasa ort ₺' + tl(ort(x => x.otuz)) + ', nakliye farkı süren ' + pct(oran(x => x.nakliye)));
  console.log('  kopuk sayfa çözüldü ' + pct(oran(x => x.coz)) + ' | izler hain adayını: 3 kişide bırakıyor ' + pct(oran(x => x.aday === 3)) + ', 2 kişiye indiriyor ' + pct(oran(x => x.aday === 2)) + ', tek kişiye indiriyor ' + pct(oran(x => x.aday === 1)));
  console.log('  kasa≥₺40.000 ve güven≥50 birlikte: ' + pct(oran(x => x.kasa >= 40000 && x.guven >= 50)) + ' | 30. gün tahmini ≥₺150.000 ve güven≥60: ' + pct(oran(x => x.otuz >= 150000 && x.guven >= 60)));
  for (const is of ['kaplıca', 'kaplıca (satıldı)', 'arı evi']) {
    const L = D.filter(x => x.is === is); if (!L.length) continue;
    console.log('  ' + is.padEnd(18) + 'pay ' + pct(L.reduce((t, x) => t + x.p, 0) / PD).padStart(6) + ' | kasa ort ₺' + tl(ort(x => x.kasa, L)) + ', güven ort ' + ort(x => x.guven, L).toFixed(1) + ', akşam net ₺' + tl(ort(x => x.net, L)) + ', 30. gün tahmini ₺' + tl(ort(x => x.otuz, L)));
  }
  const enIyi = D.reduce((b, x) => Math.min(x.otuz / 150000, x.guven / 60) > Math.min(b.otuz / 150000, b.guven / 60) ? x : b);
  console.log('  en dengeli rota: kasa ₺' + tl(enIyi.kasa) + ', güven ' + enIyi.guven + ', akşam net ₺' + tl(enIyi.net) + ', 30. gün tahmini ₺' + tl(enIyi.otuz) + ', ' + enIyi.is);
}
const esit = (id, sec) => sec.length === 1 ? [[0, 1]] : [[0, .5], [1, .5]];
analiz('Rastgele oyuncu (avukat dahil %50)', esit);
analiz('Rastgele oyuncu, avukatı reddediyor', (id, sec, o) => id === 'g7-sabah' ? [[1, 1]] : esit(id, sec));

// Tarif edilmiş oyuncu tarzları (avukatı reddeder, üç hainle)
const kalan = o => 30 - o.gun;
const puan = {
  'para (kısa vade)': (e, o) => (e.kasa || 0) + (e.gelir ? e.gelir.tutar * 3 : 0) + (e.gelirSil ? -6000 * 2 : 0) + (e.guven || 0) * 100 - (e.suphe || 0) * 100,
  'para (30 gün)': (e, o) => (e.kasa || 0) + (e.gelir ? e.gelir.tutar * kalan(o) : 0) + (e.gelirSil ? -6000 * kalan(o) : 0) + (e.guven || 0) * 800 - (e.suphe || 0) * 300,
  'köylü': (e, o) => (e.guven || 0) * 1000 + (e.kasa || 0) / 10 - (e.suphe || 0) * 200,
  'araştırmacı': (e, o) => e.yeniIpucu * 100000 + (e.guven || 0) * 1000 + (e.kasa || 0) / 10 - (e.suphe || 0) * 300,
  'temkinli': (e, o) => -(e.suphe || 0) * 2000 + (e.guven || 0) * 500 + (e.kasa || 0) / 10
};
console.log('\n## Oyuncu tarzları');
for (const [ad, f] of Object.entries(puan)) {
  const satir = [];
  for (const h of M.SUPHELILER) gez(M.yeniDurum('', h), 1, (id, sec, o) => {
    if (id === 'g7-sabah') return [[1, 1]];
    if (id === 'aksam-kopru') return [[ad === 'para (30 gün)' ? 0 : 1, 1]];
    if (sec.length === 1) return [[0, 1]];
    return [[f(sec[0], o) >= f(sec[1], o) ? 0 : 1, 1]];
  }, (s, e) => { const k = kayit(e); satir.push(h + ':' + s + ' kasa ₺' + tl(k.kasa) + ' güven ' + k.guven + ' baskı ' + k.suphe + ' net ₺' + tl(k.net) + ' 30.gün ₺' + tl(k.otuz) + ' ' + k.is + (k.nakliye ? ' +nakliye' : '') + ' çözüm ' + (k.coz ? 'var' : 'yok') + ' aday ' + k.aday); });
  console.log(ad + '\n  ' + satir.join('\n  '));
}
