# Troubleshooting Guide

## PocketIC Initialization Errors

### Error Message
```
ERROR: Failed to initialize PocketIC: HTTP status client error (400 Bad Request) for url (http://localhost:54562/instances)
```

### Common Causes

1. **dfx Version Mismatch**
   - Build system expects one version, but a different version is running
   - **Solution**: Install the required version or align versions
   ```bash
   # Check available versions
   dfxvm list
   
   # Install missing version
   dfxvm install 0.29.0
   
   # Set default version
   dfxvm default 0.29.2
   ```

2. **Multiple PocketIC Instances**
   - Multiple PocketIC servers trying to use the same port
   - **Solution**: Kill existing processes and restart
   ```bash
   # Find PocketIC processes
   ps aux | grep pocket-ic
   
   # Kill all PocketIC instances
   pkill pocket-ic
   
   # Restart dfx
   dfx start --clean
   ```

3. **Port Conflicts**
   - Another service is using PocketIC's ports (54562, 54565, etc.)
   - **Solution**: Check for port conflicts
   ```bash
   # Check what's using the ports
   lsof -i :54562 -i :54565
   
   # Kill conflicting processes if needed
   kill <PID>
   ```

4. **Corrupted .dfx Directory**
   - Corrupted state files in .dfx directory
   - **Solution**: Clean and restart
   ```bash
   # Stop dfx
   dfx stop
   
   # Remove .dfx directory (WARNING: This removes all local canister state)
   rm -rf .dfx
   
   # Restart dfx
   dfx start --clean
   ```

### Quick Fix - Stop All PocketIC/dfx Processes

**To immediately stop all PocketIC initialization errors:**

```bash
# Method 1: Kill all PocketIC processes
pkill -f "pocket-ic"

# Method 2: Kill all dfx processes
pkill -f "dfx start"

# Method 3: Use dfx stop (in project directory)
cd /path/to/your/project
dfx stop

# Method 4: Nuclear option - kill everything related
pkill -f "pocket-ic"
pkill -f "dfx start"
pkill -f "dfx"
```

**To verify everything is stopped:**
```bash
ps aux | grep -E "(pocket-ic|dfx)" | grep -v grep
# Should return nothing if all stopped
```

**Clean up port files (if errors persist):**
```bash
cd /path/to/your/project
rm -f .dfx/network/local/pocket-ic-port .dfx/network/local/pocket-ic-pid
```

### Starting Fresh

If you're seeing PocketIC errors during builds:

1. **Stop everything first**:
   ```bash
   pkill -f "pocket-ic"
   pkill -f "dfx start"
   dfx stop
   ```

2. **Ensure dfx is running** (only if you need it):
   ```bash
   dfx ping
   ```

3. **If dfx is not running and you need it**:
   ```bash
   # Start dfx in background
   dfx start --enable-bitcoin --background
   
   # Or start in foreground (in separate terminal)
   dfx start --enable-bitcoin
   ```

4. **If errors persist**, clean and restart:
   ```bash
   # Stop everything
   dfx stop
   pkill pocket-ic
   
   # Wait a moment
   sleep 2
   
   # Clean state and restart
   rm -rf .dfx/network/local/state
   dfx start --enable-bitcoin --clean
   ```

### Prevention

- Use `dfxvm` to manage dfx versions consistently
- Always stop dfx properly before closing terminal: `dfx stop`
- Use `--clean` flag sparingly (only when needed)
- Check for running dfx processes before starting: `ps aux | grep dfx`

## Internet Identity Errors

See `INTERNET_IDENTITY_SETUP.md` for detailed troubleshooting.

## Bitcoin Integration Errors

- Ensure Bitcoin node is running: `ps aux | grep bitcoind`
- Check Bitcoin RPC connection: `bitcoin-cli getblockchaininfo`
- Verify dfx started with Bitcoin: `dfx start --enable-bitcoin`

## Canister Build Errors

- Check Motoko syntax: `dfx build --check`
- Verify imports are correct
- Ensure all dependencies are installed: `mops install`

