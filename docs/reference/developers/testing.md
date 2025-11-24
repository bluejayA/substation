# Testing Guide

Substation includes a comprehensive test suite covering all major components. This guide explains how to run tests, write new tests, and understand the testing infrastructure.

## Quick Start

```bash
# Run all tests
~/.swiftly/bin/swift test

# Run tests in parallel (faster)
~/.swiftly/bin/swift test --parallel

# Run with verbose output
~/.swiftly/bin/swift test -v
```

## Test Suites

Substation currently has **36+ tests** organized into four test suites:

### OSClientTests

Tests for the OpenStack API client library.

**Coverage:**

- Configuration initialization
- Password authentication with names and IDs
- Application credential authentication
- Mixed authentication methods
- Credential validation

**Run only OSClient tests:**

```bash
~/.swiftly/bin/swift test --filter OSClientTests
```

### SubstationTests

Tests for cloud configuration, YAML parsing, and authentication management.

**Coverage:**

- YAML value processing (quotes, escapes, environment variables)
- Cloud configuration parsing
- Multiple cloud configurations
- Authentication method determination
- Configuration validation
- Secure credential storage
- Region auto-detection
- Error handling and recovery

**Run only Substation tests:**

```bash
~/.swiftly/bin/swift test --filter SubstationTests
```

**Specific test classes:**

```bash
~/.swiftly/bin/swift test --filter EnhancedCloudConfigTests
```

### MemoryManagementTests

Tests for memory safety, leak detection, and proper resource cleanup.

**Coverage:**

- Client cleanup without crashes
- Concurrent requests with cancellation
- Multiple client creation and cleanup
- Network failure recovery
- Task cancellation handling
- URLSession delegate retention
- URLSession invalidation on deinit
- Weak self in task capture

**Run only memory tests:**

```bash
~/.swiftly/bin/swift test --filter MemoryManagementTests
```

### TUITests

Tests for terminal UI components and utilities.

**Coverage:**

- Filter line matching
- Query handling

**Run only TUI tests:**

```bash
~/.swiftly/bin/swift test --filter TUITests
```

## Test Commands

### Basic Testing

```bash
# Run all tests
~/.swiftly/bin/swift test

# Run with verbose output (shows all test names)
~/.swiftly/bin/swift test -v

# Run tests in parallel for faster execution
~/.swiftly/bin/swift test --parallel
```

### Filtering Tests

```bash
# Run specific test suite
~/.swiftly/bin/swift test --filter OSClientTests

# Run specific test class
~/.swiftly/bin/swift test --filter EnhancedCloudConfigTests

# Run specific test method
~/.swiftly/bin/swift test --filter EnhancedCloudConfigTests.testBasicCloudsParsing
```

### Code Coverage

```bash
# Run tests with code coverage enabled
~/.swiftly/bin/swift test --enable-code-coverage
```

#### Generate coverage report (LCOV format)

```bash
# Note: Use Swift toolchain's llvm-cov to avoid version mismatches
~/.swiftly/bin/llvm-cov export \
  .build/debug/substationPackageTests.xctest/Contents/MacOS/substationPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata \
  -format=lcov > coverage.lcov
```

#### View coverage summary

```bash
~/.swiftly/bin/llvm-cov report \
  .build/debug/substationPackageTests.xctest/Contents/MacOS/substationPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata
```

#### Generate HTML coverage report

```bash
~/.swiftly/bin/llvm-cov show \
  .build/debug/substationPackageTests.xctest/Contents/MacOS/substationPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata \
  -format=html -output-dir=coverage-html
```

### Logging and Debugging

```bash
# Save test output to log file
~/.swiftly/bin/swift test 2>&1 | tee .build/test.log

# Run with debug logging
~/.swiftly/bin/swift test -v 2>&1 | tee .build/test-debug.log

# Show only test summary
~/.swiftly/bin/swift test 2>&1 | grep "Test Suite"
```

## Writing Tests

### Test File Structure

Test files are organized by component:

```
Tests/
|-- OSClientTests/
|   |-- OSClientTests.swift
|   +-- MemoryManagementTests.swift
|-- SubstationTests/
|   +-- EnhancedCloudConfigTests.swift
+-- TUITests/
    +-- TUITests.swift
```

### Basic Test Template

```swift
import XCTest
@testable import YourModule

final class YourTests: XCTestCase {

    // Test method - must start with "test"
    func testSomething() {
        // Arrange
        let input = "test"

        // Act
        let result = processInput(input)

        // Assert
        XCTAssertEqual(result, "expected")
    }

    // Async test
    func testAsyncOperation() async throws {
        let result = try await performAsyncOperation()
        XCTAssertNotNil(result)
    }
}
```

### Test Assertions

Common XCTest assertions:

```swift
// Equality
XCTAssertEqual(actual, expected)
XCTAssertNotEqual(actual, expected)

// Nil checking
XCTAssertNil(value)
XCTAssertNotNil(value)

// Boolean
XCTAssertTrue(condition)
XCTAssertFalse(condition)

// Error handling
XCTAssertThrowsError(try riskyOperation())
XCTAssertNoThrow(try safeOperation())

// Failure
XCTFail("Test failed with custom message")
```

### Async Testing

```swift
func testAsyncOperation() async throws {
    let manager = AuthenticationManager()
    let result = await manager.determineAuthMethod(from: config)

    XCTAssertNotNil(result)
}

func testThrowingAsyncOperation() async throws {
    let parser = EnhancedYAMLParser()
    let config = try await parser.parse(data)

    XCTAssertEqual(config.clouds.count, 1)
}
```

### Actor Testing

```swift
func testActorOperation() async {
    let storage = SecureCredentialStorage()

    // Store value
    try await storage.store("secret", for: "key")

    // Retrieve value
    let retrieved = try await storage.retrieve(for: "key")

    XCTAssertEqual(retrieved, "secret")
}
```

## Continuous Integration

All tests run automatically via GitHub Actions on every push and pull request.

### CI Workflow

The CI pipeline includes three workflows:

1. **tests.yml** - Basic test execution
2. **build.yml** - Build verification in debug and release
3. **ci.yml** - Comprehensive CI with coverage

### Workflow Triggers

Tests run on:

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

### CI Requirements

- All tests must pass
- Build must complete with zero warnings
- Code must compile in both debug and release configurations

### Viewing CI Results

1. Go to the [Actions tab](https://github.com/cloudnull/substation/actions) in GitHub
2. Click on a workflow run
3. View test results and logs
4. Download artifacts (build logs, test results, coverage reports)

## Test Best Practices

### 1. Test Naming

Use descriptive test names that explain what is being tested:

```swift
// Good
func testPasswordAuthMethodDetermination() async { }
func testApplicationCredentialParsing() async throws { }

// Bad
func testAuth() { }
func test1() { }
```

### 2. Arrange-Act-Assert Pattern

Organize tests into three clear sections:

```swift
func testExample() {
    // Arrange - Set up test data
    let input = "test"
    let expected = "result"

    // Act - Execute the code under test
    let actual = process(input)

    // Assert - Verify the result
    XCTAssertEqual(actual, expected)
}
```

### 3. Test Independence

Each test should be independent and not rely on other tests:

```swift
// Good - Self-contained test
func testUserCreation() async throws {
    let storage = SecureCredentialStorage()
    try await storage.store("value", for: "key")
    let result = try await storage.retrieve(for: "key")
    XCTAssertEqual(result, "value")
}

// Bad - Relies on previous test state
func testUserRetrieval() async throws {
    // Assumes data was stored by another test
    let result = try await storage.retrieve(for: "key")
    XCTAssertEqual(result, "value")
}
```

### 4. Use Meaningful Assertions

Provide context in assertion messages:

```swift
// Good
XCTAssertEqual(
    config.clouds.count,
    2,
    "Expected 2 clouds in configuration"
)

// Acceptable
XCTAssertEqual(config.clouds.count, 2)
```

### 5. Test Edge Cases

Don't just test the happy path:

```swift
func testEdgeCases() async throws {
    // Empty input
    let emptyResult = try await parser.parse(emptyData)
    XCTAssertEqual(emptyResult.clouds.count, 0)

    // Invalid input
    XCTAssertThrowsError(try await parser.parse(invalidData))

    // Nil handling
    let nilResult = await storage.retrieve(for: "nonexistent")
    XCTAssertNil(nilResult)
}
```

### 6. Clean Up Resources

Use defer or tearDown for cleanup:

```swift
func testWithTempFile() throws {
    let tempFile = createTempFile()
    defer { try? FileManager.default.removeItem(at: tempFile) }

    // Test code using tempFile
}
```

## Troubleshooting

### Tests Not Running

**Problem:** `swift test` hangs or doesn't execute

**Solution:**

```bash
# Clean build artifacts
rm -rf .build/

# Rebuild and test
~/.swiftly/bin/swift build
~/.swiftly/bin/swift test
```

### Compilation Errors

**Problem:** Tests don't compile

**Solution:**

1. Check that all test dependencies are available
2. Ensure `@testable import` statements are correct
3. Verify Swift version compatibility (requires Swift 6.1)

```bash
# Check Swift version
~/.swiftly/bin/swift --version
```

### Test Failures

**Problem:** Tests fail unexpectedly

**Solution:**

1. Run tests with verbose output: `swift test -v`
2. Check test logs: `.build/test.log`
3. Run specific failing test: `swift test --filter FailingTest`
4. Add debug print statements to tests

### Memory Issues

**Problem:** Tests crash or run out of memory

**Solution:**

```bash
# Run tests sequentially (not parallel)
~/.swiftly/bin/swift test

# Monitor memory during tests
top -pid $(pgrep swift-testing)
```

## Test Coverage Goals

Current test coverage:

- **OSClient**: Core functionality covered
- **Substation**: Configuration and authentication covered
- **MemoryKit**: Memory management covered
- **SwiftNCurses**: Basic components covered

### Coverage Targets

- Minimum 70% line coverage for all modules
- 100% coverage for critical paths (authentication, caching)
- All public APIs should have tests

### Measuring Coverage

```bash
# Generate coverage report
~/.swiftly/bin/swift test --enable-code-coverage

# View coverage summary
~/.swiftly/bin/llvm-cov report \
  .build/arm64-apple-macosx/debug/substationPackageTests.xctest/Contents/MacOS/substationPackageTests \
  -instr-profile=.build/arm64-apple-macosx/debug/codecov/default.profdata

# View detailed coverage
~/.swiftly/bin/llvm-cov show \
  .build/arm64-apple-macosx/debug/substationPackageTests.xctest/Contents/MacOS/substationPackageTests \
  -instr-profile=.build/arm64-apple-macosx/debug/codecov/default.profdata
```

## Next Steps

- [Developer Guide](../developers/) - Contributing guidelines
- [API Reference](../../reference/api/) - Library API documentation
- [Architecture](../../architecture/) - System design overview

## References

- [Swift Testing Documentation](https://www.swift.org/documentation/testing/)
- [XCTest Framework](https://developer.apple.com/documentation/xctest)
- [GitHub Actions for Swift](https://github.com/actions/setup-swift)
