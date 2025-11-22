# Test Failure Analysis

## Summary
- **Total Tests**: 92
- **Passing**: 60 (65%)
- **Failing**: 32 (35%)
- **Failed Suites**: 7

## Critical Issues by Category

### 1. ICP Service Tests (5 failures)

**Problem**: Module mocking breaks after `vi.resetModules()` because module references change.

**Failures**:
- `createAuthClient` - `AuthClient.create` not called after module reload
- `getIdentity` - Returns null instead of Principal
- `createActor` - Agent not initialized
- `login` - Returns null instead of Principal
- `logout` - `logout` not called

**Root Cause**: After `vi.resetModules()`, `vi.mocked()` doesn't work because:
1. The module reference changes
2. Mock setup needs to happen AFTER import, not before
3. Agent module-level state is lost

**Fix Strategy**:
- Re-apply mocks after each `vi.resetModules()`
- Mock `@dfinity/agent` before importing reloaded modules
- Set up module-level agent state properly

### 2. Hook Tests - useLending (11 failures)

**Problem**: Multiple issues with function calls and state management.

**Failures**:
- `deposit/withdraw/borrow/repay` - Functions not being called (0 calls)
- `loadUserDeposits/loadUserBorrows` - Empty arrays instead of data
- `refresh` - Function doesn't exist (should be `refetch`)
- Error handling - Errors not being set

**Root Cause**:
1. Test calls `refresh()` but hook exports `refetch`
2. `useICP` mock isn't properly set for each test
3. Functions check `isConnected` but mock returns false/null

**Fix Strategy**:
- Update test to use `refetch` instead of `refresh`
- Ensure `mockUseICP` returns connected state for each test
- Check that `isConnected` and `principal` are properly mocked

### 3. Hook Tests - usePortfolio (8 failures)

**Problem**: Portfolio not loading, undefined values.

**Failures**:
- `portfolio` is `undefined` instead of object
- Timeouts waiting for portfolio data
- Error handling timeouts

**Root Cause**:
1. `loadPortfolio` depends on `isConnected && principal` but mock state isn't set
2. Tests set mock state but it doesn't trigger useEffect
3. Missing proper `waitFor` with sufficient timeouts

**Fix Strategy**:
- Set `mockUseICP` BEFORE rendering hook
- Use `rerender()` to trigger useEffect when mock changes
- Add proper `waitFor` with longer timeouts for async operations

### 4. Hook Tests - useRewards (4 failures)

**Problem**: Validation checks fail before reaching actual validation.

**Failures**:
- `trackPurchase` not called - returns early with "Must be connected"
- Validation tests fail with wrong error message

**Root Cause**:
1. `mockUseICP.mockReturnValueOnce` doesn't persist across hook renders
2. Connection check happens before validation
3. Mock needs to be set before hook renders, not during test

**Fix Strategy**:
- Set `mockUseICP` to return connected state at test start
- Use `mockReturnValue` instead of `mockReturnValueOnce` for connected tests
- Ensure mock is set before `renderHook`

### 5. Hook Tests - useSwap (3 failures)

**Problem**: Type mismatches and function calls not happening.

**Failures**:
- `getQuote` - Called with `1000` (number) instead of `BigInt(1000)`
- `executeSwap` - Not called (0 calls)
- `getSwapHistory` - Not called

**Root Cause**:
1. Test passes number to `getQuote` but expects BigInt
2. `executeSwap` checks authentication but mock isn't connected
3. `getSwapHistory` also checks authentication

**Fix Strategy**:
- Fix test to pass `BigInt(1000)` to `getQuote`
- Ensure `mockUseICP` returns connected state for these tests
- Check that authentication checks pass

## Recommended Fix Order

1. **High Priority**: Fix `useLending` refresh → refetch rename
2. **High Priority**: Fix ICP service tests - re-apply mocks after resetModules
3. **Medium Priority**: Fix hook authentication mocking - ensure connected state
4. **Medium Priority**: Fix useSwap type mismatches
5. **Low Priority**: Add better error messages and timeouts

## Pattern Issues

### Common Pattern 1: Mock State Not Persisting
```typescript
// ❌ BAD - Mock set after render
const { result } = renderHook(() => useHook())
mockUseICP.mockReturnValueOnce({ isConnected: true })

// ✅ GOOD - Mock set before render
mockUseICP.mockReturnValue({ isConnected: true, principal: mockPrincipal })
const { result } = renderHook(() => useHook())
```

### Common Pattern 2: Module Mocking After Reset
```typescript
// ❌ BAD - Mock before reset
vi.mocked(AuthClient.create).mockResolvedValue(...)
await vi.resetModules()

// ✅ GOOD - Mock after reset
await vi.resetModules()
vi.mocked(AuthClient.create).mockResolvedValue(...)
```

### Common Pattern 3: Missing waitFor with Timeouts
```typescript
// ❌ BAD - No timeout
await waitFor(() => expect(result.current.data).toBeDefined())

// ✅ GOOD - With timeout
await waitFor(() => expect(result.current.data).toBeDefined(), { timeout: 5000 })
```

## Files Needing Updates

1. `src/hooks/__tests__/useLending.test.ts` - Change `refresh` to `refetch`
2. `src/services/__tests__/icp.test.ts` - Fix module mocking after resetModules
3. `src/hooks/__tests__/usePortfolio.test.ts` - Fix mock state setup
4. `src/hooks/__tests__/useRewards.test.ts` - Fix authentication mocking
5. `src/hooks/__tests__/useSwap.test.ts` - Fix type mismatches and auth

## Estimated Fix Time

- Quick fixes (refresh/refetch, type issues): 15 minutes
- ICP service mocking fixes: 30-45 minutes
- Hook authentication mocking: 30-45 minutes
- Total: ~1.5-2 hours

