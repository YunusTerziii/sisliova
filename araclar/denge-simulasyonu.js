// Kullanım: node --stack-size=8000 araclar/denge-simulasyonu.js
// Oyunun gerçek motor bölümünü (MOTOR BAŞI..MOTOR SONU) yükleyip bütün yolları gezer
const fs = require('fs');
const src = fs.readFileSync(process.argv[2] || require('path').join(__dirname, '../oyun/index.html'), 'utf8');
const motor = src.slice(src.indexOf('// ===== MOTOR BAŞI'), src.indexOf('// ===== MOTOR SONU'));
const M = new Function(motor + '; return { DESTE, siradakiKart, cozSecim, uygula, ilerle, aksamHesapla, sinirKontrol, cozuldu, yeniDurum, SUPHELILER, HEDEF_KASA, GUVEN_YUKSEK };')();
const klon = o => JSON.parse(JSON.stringify(o));

// Bir durumdan oyun sonuna kadar: secici(kart, secenekler, o) -> [[indeks, olasılık], ...]
function gez(o, p, secici, cik, kayit) {
  const kart = M.siradakiKart(o);
  if (!kart) throw new Error('kart yok ' + o.gun + ' ' + o.anIndex);
  const sec = [kart.a, kart.b].filter(Boolean).map(s => M.cozSecim(kart, s, o));
  for (const [i, pi] of secici(kart, sec, o)) {
    const e = klon(o); const yol = kayit.concat(kart.id + '-' + 'ab'[i]);
    M.uygula(sec[i], e);
    if (sec[i].son) { cik(sec[i].son, e, p * pi, yol); continue; }
    let s = M.sinirKontrol(e); if (s) { cik(s, e, p * pi, yol); continue; }
    if (M.ilerle(e) === 'aksam') { M.aksamHesapla(e); s = M.sinirKontrol(e); if (s) { cik(s, e, p * pi, yol); continue; } }
    gez(e, p * pi, secici, cik, yol);
  }
}
const esit = (k, sec) => sec.length === 1 ? [[0, 1]] : [[0, .5], [1, .5]];
const reddet = (k, sec, o) => k.id === 'g7-sabah' ? [[1, 1]] : esit(k, sec);

function analiz(ad, secici) {
  const top = { yol: 0, son: {}, p: {}, demo: [], };
  for (const h of M.SUPHELILER) {
    gez(M.yeniDurum('', h), 1 / 3, secici, (son, e, p, yol) => {
      top.yol++; top.son[son] = (top.son[son] || 0) + 1; top.p[son] = (top.p[son] || 0) + p;
      if (son === 'demo') top.demo.push({ p, kasa: e.kasa, guven: e.guven, suphe: e.suphe, coz: M.cozuldu(e), is: e.bayraklar.kaplica ? 'kaplica' : 'ari', satildi: !!e.bayraklar.kaplicaSatildi, ip: e.ipuclari.length, kisi: e.ipuclari.filter(i => i.kisi === e.hain && i.tur === 'iz').length });
    }, []);
  }
  const pct = x => (x * 100).toFixed(1) + '%';
  console.log('\n## ' + ad);
  console.log('yaprak sayısı', top.yol, JSON.stringify(top.son));
  console.log('ağırlıklı sonuç', Object.entries(top.p).map(([k, v]) => k + ' ' + pct(v)).join(', '));
  const D = top.demo, PD = D.reduce((t, x) => t + x.p, 0);
  const ort = f => D.reduce((t, x) => t + x.p * f(x), 0) / PD;
  const oran = f => D.filter(f).reduce((t, x) => t + x.p, 0) / PD;
  const yuzdelik = (f, q) => { const s = D.map(x => [f(x), x.p]).sort((a, b) => a[0] - b[0]); let c = 0; for (const [v, p] of s) { c += p; if (c >= q * PD) return v; } };
  console.log('7. günü bitirenlerde (ağırlıklı): kasa ort ' + Math.round(ort(x => x.kasa)) + ' (alt %10 ' + yuzdelik(x => x.kasa, .1) + ', üst %10 ' + yuzdelik(x => x.kasa, .9) + ', en yüksek ' + D.reduce((m, x) => Math.max(m, x.kasa), -1e9) + ')');
  console.log('  güven ort ' + ort(x => x.guven).toFixed(1) + ', güven≥60 ' + pct(oran(x => x.guven >= 60)) + ', güven<25 ' + pct(oran(x => x.guven < 25)) + ', baskı≥50 ' + pct(oran(x => x.suphe >= 50)));
  console.log('  kopuk sayfa çözüldü ' + pct(oran(x => x.coz)) + ', haine dair en az bir iz ' + pct(oran(x => x.kisi > 0)) + ', ipucu ort ' + ort(x => x.ip).toFixed(1));
  for (const is of ['kaplica', 'ari']) {
    const S = D.filter(x => x.is === is), P = S.reduce((t, x) => t + x.p, 0);
    console.log('  ' + is + ': kasa ort ' + Math.round(S.reduce((t, x) => t + x.p * x.kasa, 0) / P) + ', güven ort ' + (S.reduce((t, x) => t + x.p * x.guven, 0) / P).toFixed(1) + ', pay ' + pct(P / PD));
  }
}
analiz('Her seçenek %50 (avukat dahil)', esit);
analiz('Her seçenek %50, avukat reddediliyor', reddet);

// Tarif edilmiş oyuncu stratejileri (tek yol, 3 hain için)
const kalanAksam = o => Math.max(0, 7 - o.gun + (o.anIndex <= 1 ? 1 : 0) - 1);
const puan = {
  para: (e, o) => (e.kasa || 0) + (e.gelir ? e.gelir.tutar * (kalanAksam(o) + 1) : 0) + (e.gelirSil ? -6000 * kalanAksam(o) : 0) + (e.guven || 0) * 100 - (e.suphe || 0) * 100,
  koylu: (e, o) => (e.guven || 0) * 1000 + (e.kasa || 0) / 10 - (e.suphe || 0) * 200,
  arastirmaci: (e, o) => e.yeniIpucu * 100000 + (e.guven || 0) * 1000 + (e.kasa || 0) / 10 - (e.suphe || 0) * 300,
  temkinli: (e, o) => -(e.suphe || 0) * 2000 + (e.guven || 0) * 500 + (e.kasa || 0) / 10
};
for (const [ad, f] of Object.entries(puan)) {
  for (const h of M.SUPHELILER) {
    gez(M.yeniDurum('', h), 1, (k, sec, o) => {
      if (k.id === 'g7-sabah') return [[1, 1]];
      if (sec.length === 1) return [[0, 1]];
      return [[f(sec[0], o) >= f(sec[1], o) ? 0 : 1, 1]];
    }, (son, e, p, yol) => console.log(ad.padEnd(12), 'hain=' + h.padEnd(6), son.padEnd(6), 'kasa ' + e.kasa, 'güven ' + e.guven, 'baskı ' + e.suphe, 'çözüldü ' + M.cozuldu(e), 'ipucu ' + e.ipuclari.length), []);
  }
}
