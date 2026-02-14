# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.0.x   | :white_check_mark: |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: security@foodshare.club

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

Please include the following information:

- Type of issue (e.g. buffer overflow, SQL injection, cross-site scripting, etc.)
- Full paths of source file(s) related to the manifestation of the issue
- The location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

## Security Best Practices

### For Users
- Use a strong, unique password
- Enable two-factor authentication when available
- Keep your app updated to the latest version
- Don't share your account credentials
- Report suspicious activity immediately

### For Developers
- Never commit secrets, API keys, or passwords to the repository
- Use environment variables for sensitive configuration
- Follow secure coding practices
- Keep dependencies up to date
- Review code for security issues before merging
- Use HTTPS for all API communications
- Implement proper input validation
- Follow principle of least privilege

## Known Security Considerations

### Current Implementation
- JWT tokens stored in device secure storage (Keychain/EncryptedSharedPreferences)
- All API calls use HTTPS
- Row-level security enabled in Supabase
- No sensitive data in client-side code
- Input validation on both client and server

### Planned Improvements
- Two-factor authentication
- Biometric authentication
- Enhanced session management
- Security audit before production release

## Disclosure Policy

When we receive a security bug report, we will:

1. Confirm the problem and determine affected versions
2. Audit code to find similar problems
3. Prepare fixes for all supported versions
4. Release patches as soon as possible

## Comments

If you have suggestions on how this process could be improved, please submit a pull request.
