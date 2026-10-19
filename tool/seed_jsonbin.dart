import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:learnsphere/data/jsonbin_store.dart';

import 'seed_data.dart';

const domains = ['users', 'courses', 'enrollments'];

List<JsonBinStore> configuredStores(Record config, http.Client client) {
  String value(String key, [String fallback = '']) {
    if (!config.containsKey(key)) return fallback;
    if (config[key] is! String) {
      throw const FormatException('Configuration values must be strings.');
    }
    return (config[key] as String).trim();
  }

  final stores = <JsonBinStore>[];
  for (final domain in domains) {
    final prefix = 'JSONBIN_${domain.toUpperCase()}';
    final id = value(
      '${prefix}_BIN_ID',
      domain == 'users'
          ? value('JSONBIN_BIN_ID', '6ad47a60ac6210605a3b7e6e')
          : '',
    );
    final master = value('${prefix}_MASTER_KEY', value('JSONBIN_MASTER_KEY'));
    final access = value('${prefix}_ACCESS_KEY', value('JSONBIN_ACCESS_KEY'));
    if (id.isEmpty || (master.isEmpty && access.isEmpty)) {
      throw FormatException('Missing $domain bin ID or credentials.');
    }
    stores.add(
      JsonBinStore(
        client: client,
        binId: id,
        masterKey: master,
        accessKey: access,
      ),
    );
  }
  if (stores.map((s) => s.binId).toSet().length != 3) {
    throw const FormatException('The three domains must use different bins.');
  }
  return stores;
}

class SeedApplyException implements Exception {
  SeedApplyException(this.confirmed, this.domain);
  final List<String> confirmed;
  final String domain;
  @override
  String toString() =>
      'Stopped at $domain. Confirmed writes: ${confirmed.isEmpty ? "none" : confirmed.join(", ")}. The failed write may have reached JSONBin; read back before retrying. Backups are retained.';
}

Future<void> applySeed(List<JsonBinStore> stores, SeedPlan plan) async {
  final confirmed = <String>[];
  for (var i = 0; i < 3; i++) {
    if (jsonEncode(plan.before[i]) == jsonEncode(plan.after[i])) continue;
    try {
      // Detect edits made since preview/backups before replacing a whole bin.
      final latest = await stores[i].read(operation: 'Seed preflight');
      if (jsonEncode(latest) != jsonEncode(plan.before[i])) {
        throw const FormatException('Store changed during seeding.');
      }
      await stores[i].write(plan.after[i], operation: 'Seed ${domains[i]}');
      confirmed.add(domains[i]);
    } catch (_) {
      throw SeedApplyException(List.of(confirmed), domains[i]);
    }
  }
}

Future<void> main(List<String> args) async {
  final client = http.Client();
  try {
    if (args.any(
          (a) =>
              a != '--apply' && a != '--preview' && !a.startsWith('--config='),
        ) ||
        (args.contains('--apply') && args.contains('--preview'))) {
      throw const FormatException(
        'Usage: dart run tool/seed_jsonbin.dart [--preview|--apply] [--config=jsonbin.local.json]',
      );
    }
    final configArg = args.where((a) => a.startsWith('--config=')).firstOrNull;
    final path = configArg == null
        ? 'jsonbin.local.json'
        : configArg.substring(9);
    final config = jsonDecode(await File(path).readAsString()) as Record;
    final stores = configuredStores(config, client);
    final source = <Record>[];
    for (final store in stores) {
      source.add(await store.read(operation: 'Seed preview'));
    }
    final plan = buildSeed(source, DateTime.now().toUtc());
    stdout.writeln(
      'Additions: ${plan.added[0]} learners, ${plan.added[1]} courses, ${plan.added[2]} enrollments.',
    );
    stdout.writeln(
      'Totals: ${domains.indexed.map((d) => "${(plan.after[d.$1][d.$2] as List).length} ${d.$2}").join(", ")}.',
    );
    if (!args.contains('--apply')) {
      stdout.writeln(
        'Preview only. Use --apply to back up and write these stores.',
      );
      return;
    }
    final directory = Directory(
      '.local/seed-backups/${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    for (var i = 0; i < 3; i++) {
      await File('${directory.path}/${domains[i]}.json')
          .writeAsString(encoder.convert(plan.before[i]), flush: true);
    }
    final learners = records(plan.after[0], 'users').where(
      (u) => (u['seed_id'] as String? ?? '').startsWith('$seedTag-learner-'),
    );
    await File('${directory.path}/learner-signins.json').writeAsString(
      encoder.convert([
        for (final u in learners)
          {
            'name': u['full_name'],
            'username': u['username'],
            'email': u['email'],
            'is_active': u['is_active'],
            'initial_seed_password': seedPassword,
          },
      ]),
      flush: true,
    );
    stdout.writeln(
      'Local backups and initial test sign-ins: ${directory.path}',
    );
    await applySeed(stores, plan);
    final verified = <Record>[];
    for (var i = 0; i < 3; i++) {
      final record = await stores[i].read(operation: 'Seed verification');
      if (jsonEncode(record) != jsonEncode(plan.after[i])) {
        throw const FormatException(
          'Read-back differs from planned data. Inspect stores before retrying.',
        );
      }
      verified.add(record);
    }
    validateDataset(verified);
    stdout.writeln('Verified all three stores. Seed complete.');
  } on SeedApplyException catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  } on JsonBinException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } on FormatException {
    stderr.writeln(
      'Invalid configuration, conflicting identities, or invalid dataset. No further writes attempted.',
    );
    exitCode = 1;
  } catch (_) {
    stderr.writeln(
      'Seed stopped because a local file or network operation failed. Check configuration and retained backups.',
    );
    exitCode = 1;
  } finally {
    client.close();
  }
}
