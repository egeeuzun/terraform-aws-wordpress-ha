// Faz 6 olcumu: ayni senaryolari bir ortama karsi calistirir, her senaryo
// icin TTFB'yi (k6 http_req_waiting) ttfb_<senaryo> metriginde toplar.
// Yuk testi degil; 1 sanal kullanici, kullanici deneyimi olcumu.
//
//   k6 run -e BASE=https://dxxxx.cloudfront.net \
//     -e CATEGORY=/urun-kategori/<slug>/ -e PRODUCT=/urun/<slug>/ -e PRODUCT_ID=<id> \
//     --summary-export raw/fra-r1.json --out csv=raw/fra-r1.csv bench/olcum.js
//
// ORDER=1 kapida odemeyle siparis de verir (stok duser; ayri turda calistirin).
// ITER her senaryonun tekrar sayisi (varsayilan 50).
import http from 'k6/http';
import { check } from 'k6';
import { Trend } from 'k6/metrics';

const BASE = __ENV.BASE;
const P = {
  static: __ENV.STATIC || '/wp-content/themes/shopdemo/style.css',
  category: __ENV.CATEGORY,
  product: __ENV.PRODUCT,
  account: __ENV.ACCOUNT || '/hesabim/',
  checkout: __ENV.CHECKOUT || '/odeme/',
};
const ORDER = __ENV.ORDER === '1';

const names = ['static', 'zone', 'home', 'category', 'product', 'add_to_cart', 'checkout', 'account'];
const ttfb = Object.fromEntries(names.map((n) => [n, new Trend(`ttfb_${n}`, true)]));

export const options = {
  vus: 1,
  iterations: Number(__ENV.ITER || 50),
  summaryTrendStats: ['med', 'p(95)', 'count'],
  thresholds: { checks: ['rate>0.99'] },
};

function req(name, res) {
  ttfb[name].add(res.timings.waiting);
  check(res, {
    [`${name} 2xx`]: (r) => r.status >= 200 && r.status < 300,
    // Turkiye'den olcum: istek Istanbul edge'inden gecmeli
    'edge IST': (r) => (r.headers['X-Amz-Cf-Pop'] || '').startsWith('IST'),
  });
  return res;
}

function nonce(res, field) {
  return res.html().find(`input[name="${field}"]`).attr('value');
}

export default function () {
  // Demo musteri olarak bir kez giris; cerez VU boyunca kalir
  if (__ITER === 0) {
    const page = http.get(`${BASE}${P.account}`);
    http.post(`${BASE}${P.account}`, {
      username: 'demo.musteri@example.com',
      password: 'demo123',
      'woocommerce-login-nonce': nonce(page, 'woocommerce-login-nonce'),
      _wp_http_referer: P.account,
      login: '1',
    });
  }

  req('static', http.get(`${BASE}${P.static}`));
  req('zone', http.get(`${BASE}/zone.php`));
  req('home', http.get(`${BASE}/`));
  req('category', http.get(`${BASE}${P.category}`));
  req('product', http.get(`${BASE}${P.product}`));
  req('add_to_cart', http.post(`${BASE}/?wc-ajax=add_to_cart`, {
    product_id: __ENV.PRODUCT_ID,
    quantity: '1',
  }));
  const account = req('account', http.get(`${BASE}${P.account}orders/`));
  check(account, { 'giris yapilmis': (r) => !r.body.includes('woocommerce-form-login') });

  if (ORDER) {
    const page = http.get(`${BASE}${P.checkout}`);
    const res = req('checkout', http.post(`${BASE}/?wc-ajax=checkout`, {
      billing_first_name: 'Demo', billing_last_name: 'Musteri',
      billing_country: 'TR', billing_state: 'TR34', billing_city: 'İstanbul',
      billing_address_1: 'Test Sok. 1', billing_postcode: '34000',
      billing_phone: '+905550000000', billing_email: 'demo.musteri@example.com',
      billing_tckn: '10000000146', // sentetik, saglama kuralina uyar
      payment_method: 'cod',
      'woocommerce-process-checkout-nonce': nonce(page, 'woocommerce-process-checkout-nonce'),
    }));
    if (!check(res, { 'siparis olustu': (r) => r.json('result') === 'success' })) {
      console.warn(res.body.slice(0, 300)); // eksik alan varsa burada gorunur
    }
  }
}
