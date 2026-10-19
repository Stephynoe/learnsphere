import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:learnsphere/admin/admin_courses_repository.dart';
import 'package:learnsphere/data/jsonbin_store.dart';

import 'lesson_content.dart';
import 'seed_data.dart';
import 'seed_jsonbin.dart' show configuredStores;

class ContentUpdate {
  ContentUpdate(this.record, this.updated, this.skipped, this.current);
  final Record record;
  final int updated, skipped, current;
}

ContentUpdate updateContent(Record source) {
  final result = jsonDecode(jsonEncode(source)) as Record;
  final courses = parseCourses(jsonDecode(jsonEncode(source)) as Record);
  var updated = 0, skipped = 0, current = 0;
  for (var c = 0; c < subjects.length; c++) {
    final id = '$seedTag-course-${c + 1}';
    final course = courses.where((course) => course.id == id).firstOrNull;
    if (course == null) continue;
    if (course.data['seed_id'] != id) {
      throw const FormatException('Conflicting demo course identifier.');
    }
    for (var m = 0; m < 3; m++) {
      for (var l = 0; l < 3; l++) {
        final lessonId = '$id-m$m-${['intro', 'lab', 'check'][l]}';
        final lesson = course.lessons
            .where((lesson) => lesson['id'] == lessonId)
            .firstOrNull;
        if (lesson == null) {
          skipped++;
          continue;
        }
        final replacement = lessonContent(c, m, l);
        if (lesson['content'] == replacement) {
          current++;
        } else if (lesson['content'] ==
            originalLessonContent(subjects[c][0], subjects[c][m + 3], l)) {
          lesson['content'] = replacement;
          updated++;
        } else {
          skipped++;
        }
      }
    }
  }
  // Use the original maps: parsing may synthesize IDs for unrelated legacy data.
  // Only matched demo lesson content is copied back, leaving every other field intact.
  for (final raw in result['courses'] as List) {
    final course = courses.firstWhere((c) => c.id == raw['id']);
    if (!(raw['id'] as String).startsWith('$seedTag-course-')) continue;
    for (final module in raw['modules'] as List) {
      for (final lesson in module['lessons'] as List) {
        final parsed = course.lessons
            .where((l) => l['id'] == lesson['id'])
            .firstOrNull;
        if (parsed != null) lesson['content'] = parsed['content'];
      }
    }
  }
  return ContentUpdate(result, updated, skipped, current);
}

Future<void> saveContent(
  JsonBinStore store,
  Record before,
  Record after,
) async {
  final latest = await store.read(operation: 'Lesson update preflight');
  if (jsonEncode(latest) != jsonEncode(before)) {
    throw const FormatException(
      'Courses changed since preview; rerun the preview.',
    );
  }
  await store.write(after, operation: 'Demo lesson update');
  final verified = await store.read(operation: 'Lesson update verification');
  if (jsonEncode(verified) != jsonEncode(after)) {
    throw const FormatException(
      'Read-back differs from the update; inspect courses before retrying.',
    );
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
        'Use --preview or --apply and optional --config=path.json.',
      );
    }
    final configArg = args.where((a) => a.startsWith('--config=')).firstOrNull;
    final path = configArg == null
        ? 'jsonbin.local.json'
        : configArg.substring(9);
    final config = jsonDecode(await File(path).readAsString()) as Record;
    final store = configuredStores(config, client)[1];
    final before = await store.read(operation: 'Demo lesson preview');
    final update = updateContent(before);
    stdout.writeln(
      'Lessons: ${update.updated} to update, ${update.current} already current, ${update.skipped} edited or missing (preserved).',
    );
    if (!args.contains('--apply') || update.updated == 0) {
      stdout.writeln('No writes performed.');
      return;
    }
    final directory = Directory(
      '.local/seed-backups/content-${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    await File('${directory.path}/courses.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(before),
      flush: true,
    );
    stdout.writeln('Courses backup: ${directory.path}/courses.json');
    await saveContent(store, before, update.record);
    stdout.writeln(
      'Updated and verified courses. Users and enrollments were not written.',
    );
  } on JsonBinException catch (e) {
    stderr.writeln(
      '${e.message} Retain the backup and inspect courses before retrying.',
    );
    exitCode = 1;
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } catch (_) {
    stderr.writeln(
      'Lesson update stopped. Check local configuration and retained backups before retrying.',
    );
    exitCode = 1;
  } finally {
    client.close();
  }
}
