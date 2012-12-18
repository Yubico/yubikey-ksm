yubikey-ksm
===========

The YubiKey Key Storage Module (YK-KSM) provides a AES key storage facility for use with a YubiKey validation server.
The YK-KSM is intended to be run on a locked-down server.
This separation allows third parties to keep tight control of the AES keys for their YubiKeys, but at the same time allow external validation servers (e.g., Yubico's) to validate OTPs from these YubiKeys.



The YK-KSM was designed to work with the YubiKey validation server in PHP:

https://github.com/Yubico/yubikey-val-server-php/
