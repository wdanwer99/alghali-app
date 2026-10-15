// Collects what integration_test/perf_test.dart measured (`pnpm perf:e2e`) and writes it
// to build/integration_response_data.json.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
