---
name: writing-tests
description: >
  This skill should be used when writing tests, adding test coverage, reviewing
  test quality, fixing failing tests, or writing assertions. Applies to any
  language or test framework. Covers assertion-quality rules that ensure tests
  catch real bugs rather than passing vacuously.
---

# Writing Tests

Rules for writing tests that actually catch bugs. Focus on assertion-quality
discipline — making sure every test verifies what it claims to verify.

## Rules

### Assert exact expected values, not just existence

When test fixtures inject specific values, assertions must verify those exact values.
Weak assertions like `is not None` or `assertTrue(result)` pass even when the wrong
value is returned, defeating the purpose of the test.

```python
# BAD — passes even if get_model() returns the wrong model
settings = create_settings(model="gpt-4.1-mini")
assert settings.model is not None

# GOOD — catches regressions in value resolution
settings = create_settings(model="gpt-4.1-mini")
assert settings.model == "gpt-4.1-mini"
```

**The principle:** if a fixture sets a value, the test should close the loop by
asserting that exact value flows through correctly. The fixture and the assertion
are two halves of the same contract.
