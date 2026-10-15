import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

const accent = Color(0xFFFF5A36);
const green = Color(0xFF12A150);
const siteUrl = 'https://mchipta.github.io/delo-est/';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.load();
  runApp(const DeloEstApp());
}

class DeloEstApp extends StatelessWidget {
  const DeloEstApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ДелоЕсть',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: accent,
            scaffoldBackgroundColor: const Color(0xFFFDF8F3)),
        darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: accent, brightness: Brightness.dark),
        home: const Shell(),
      );
}

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<void> open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: tab, children: const [AdsPage(), AccountPage()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search), label: 'Объявления'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Кабинет'),
          ],
        ),
      );
}

// ---------- Список объявлений ----------

class AdsPage extends StatefulWidget {
  const AdsPage({super.key});
  @override
  State<AdsPage> createState() => _AdsPageState();
}

class _AdsPageState extends State<AdsPage> {
  List<Ad> ads = [];
  bool loading = true;
  String? error;
  String q = '';

  @override
  void initState() {
    super.initState();
    Api.auth.addListener(load);
    load();
  }

  @override
  void dispose() {
    Api.auth.removeListener(load);
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = ads.isEmpty;
      error = null;
    });
    try {
      final j = await Api.call('ads');
      final l = (j['ads'] as List).map((e) => Ad(Map<String, dynamic>.from(e))).toList()
        ..sort((a, b) => b.ts.compareTo(a.ts));
      if (!mounted) return;
      setState(() => ads = l);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = ads
        .where((a) => q.isEmpty || '${a.title} ${a.desc} ${a.city}'.toLowerCase().contains(q.toLowerCase()))
        .toList();
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'Поиск: грузчик, уборка…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null && ads.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(error!),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: load, child: const Text('Повторить')),
                    ]))
                  : RefreshIndicator(
                      onRefresh: load,
                      child: f.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 120),
                              Center(child: Text('Ничего не найдено')),
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: f.length,
                              itemBuilder: (_, i) => AdCard(f[i]),
                            ),
                    ),
        ),
      ]),
    );
  }
}

class AdCard extends StatelessWidget {
  final Ad ad;
  const AdCard(this.ad, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdPage(ad))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 96,
                height: 96,
                child: ad.imgs.isEmpty
                    ? Container(color: cs.primaryContainer, child: Icon(Icons.work_outline, color: cs.primary, size: 36))
                    : CachedNetworkImage(imageUrl: imgUrl(ad.imgs.first, 300), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ad.type, style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(ad.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(ad.pay, style: const TextStyle(color: green, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${ad.city.isEmpty ? 'Город не указан' : ad.city} · ${ad.date}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------- Страница объявления ----------

class AdPage extends StatelessWidget {
  final Ad ad;
  const AdPage(this.ad, {super.key});

  String get digits {
    var d = ad.phone.replaceAll(RegExp(r'\D'), '');
    if (d.length == 11 && d.startsWith('8')) d = '7${d.substring(1)}';
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logged = Api.user != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Объявление')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (ad.imgs.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: PageView(
                children: ad.imgs
                    .map((i) => CachedNetworkImage(imageUrl: imgUrl(i, 1000), fit: BoxFit.cover))
                    .toList(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          Chip(label: Text(ad.type)),
          Chip(label: Text(ad.category)),
        ]),
        Text(ad.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(ad.pay, style: const TextStyle(fontSize: 22, color: green, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${ad.city.isEmpty ? 'Город не указан' : ad.city} · ${ad.date}',
            style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        const Text('Описание', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(ad.desc, style: const TextStyle(fontSize: 16, height: 1.5)),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Автор: ${ad.author}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (!logged)
                const Text('Войдите в аккаунт (вкладка «Кабинет»), чтобы увидеть контакты.')
              else if (ad.phone.isEmpty)
                const Text('Телефон не указан')
              else ...[
                FilledButton.icon(
                  onPressed: () => open('tel:${ad.phone.replaceAll(RegExp(r'[^\d+]'), '')}'),
                  icon: const Icon(Icons.call),
                  label: Text('Позвонить: ${ad.phone}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => open(
                      'https://wa.me/$digits?text=${Uri.encodeComponent('Здравствуйте! Пишу по объявлению «${ad.title}» на ДелоЕсть')}'),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => open('https://t.me/+$digits'),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Telegram'),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------- Кабинет: вход ----------

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    Api.auth.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Api.auth.removeListener(_refresh);
    super.dispose();
  }

  Future<void> login() async {
    final em = email.text.trim().toLowerCase();
    if (em.isEmpty || pass.text.isEmpty) {
      toast(context, 'Введите почту и пароль');
      return;
    }
    setState(() => busy = true);
    try {
      final j = await Api.call('login', {'login': em, 'hash': sha('$em:${pass.text}')});
      await Api.save({
        't': j['t'],
        'login': j['login'],
        'name': j['name'],
        'phone': j['phone'],
        'pid': j['pid'],
      });
      pass.clear();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = Api.user;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 12),
        Text(u == null ? 'Вход' : 'Кабинет', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (u == null) ...[
          TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Почта', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: busy ? null : login,
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Войти')),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => open('${siteUrl}#/cab'),
              child: const Text('Регистрация и сброс пароля: на сайте')),
        ] else ...[
          ListTile(leading: const Icon(Icons.person_outline), title: Text('${u['name']}'), subtitle: const Text('Имя')),
          ListTile(leading: const Icon(Icons.mail_outline), title: Text('${u['login']}'), subtitle: const Text('Почта')),
          ListTile(leading: const Icon(Icons.phone_outlined), title: Text('${u['phone']}'), subtitle: const Text('Телефон')),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => Api.save(null), child: const Text('Выйти')),
        ],
      ]),
    );
  }
}
