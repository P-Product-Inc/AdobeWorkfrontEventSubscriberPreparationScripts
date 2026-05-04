# JWT Asset Preparation Scripts

This repository helps you generate the crypto files needed for a JWT-based integration.

In simple terms, the scripts create:

- a public certificate you can upload to your target system
- a private key package you can store securely
- a serialized private key representation you can pass into lightweight runtimes such as `.NET Standard 2.0` code or Power Automate connector scripts

There are two implementations of the same idea:

- `WindowsPowerShell/` for Windows users
- `LinuxPythonBash/` for Linux-style usage through Docker

The Linux flow uses Docker on purpose so you do not need to install OpenSSL and Python crypto libraries directly on your host machine.

## What This Repository Contains

- `WindowsPowerShell/jwt-token-generate-jwt-assets.ps1`
  Native Windows PowerShell script. It creates a self-signed RSA certificate, exports the public certificate, creates a `.pfx`, and serializes RSA private parameters.
- `LinuxPythonBash/generate_jwt_assets.sh`
  Bash script that uses OpenSSL plus a small embedded Python step to serialize the RSA private key into JSON and Base64.
- `LinuxPythonBash/Dockerfile`
  Docker image definition with OpenSSL, Python, and the `cryptography` package.
- `LinuxPythonBash/docker-compose.yml`
  Docker Compose wrapper that mounts this repository into the container so the generated files are saved back into your project folder.

## What Files Get Generated

After you run either script, you will get most or all of these files in an output folder:

- `certificate_pub.crt`
  Public certificate. This is the main file you upload to your JWT/OAuth app configuration.
- `certificate_pub.cer`
  Windows only. Another public certificate export format.
- `certificate_pub.pem`
  Linux only. PEM copy of the public certificate.
- `private_key.pfx`
  PKCS#12 bundle that contains the private key and certificate.
- `private_key_pfx_password.txt`
  Password for the `.pfx` file.
- `private_key_pfx_base64.txt`
  Same `.pfx` file encoded as one Base64 string.
- `rsa-params.json`
  Human-readable JSON with the RSA private parameters.
- `rsa_params.min.b64.txt`
  The same RSA parameter payload minified and then Base64-encoded into one line. This is usually the easiest file to pass into lightweight connector/runtime scenarios.

## Which File Should I Use

If you are not sure which output to use, follow this:

- Need to configure your target system: use `certificate_pub.crt`
- Need a standard private key bundle: use `private_key.pfx` and `private_key_pfx_password.txt`
- Need a single-line serialized private key value: use `rsa_params.min.b64.txt`
- Need to inspect or debug the private key structure: open `rsa-params.json`

## Important Safety Notes

- Treat everything except the public certificate files as secret.
- Do not commit generated key files into source control.
- Share the private key files only through a secure secret-management process.

## Windows Usage

### Before You Start

You need:

- Windows
- PowerShell
- Permission to create a self-signed certificate in your current user certificate store

### Quick Start

Run this from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\WindowsPowerShell\jwt-token-generate-jwt-assets.ps1
```

### Where The Files Go

By default, the Windows script writes files to:

```text
.\jwt-keys\jwt-assets
```

### Custom Example

Use a different output folder and certificate lifetime:

```powershell
powershell -ExecutionPolicy Bypass -File .\WindowsPowerShell\jwt-token-generate-jwt-assets.ps1 -OutDir "..\jwt-keys\my-custom-assets" -YearsValid 3
```

### What The Windows Script Does

Step by step, the script:

1. Creates a new 2048-bit self-signed RSA certificate
2. Exports the public certificate as `.cer` and `.crt`
3. Exports the private key as `.pfx`
4. Generates a random password for the `.pfx`
5. Converts the `.pfx` into a one-line Base64 value
6. Exports RSA private parameters into JSON
7. Creates a one-line Base64 version of the minified RSA JSON

## Linux Usage Through Docker

### Before You Start

You need:

- Docker Desktop, or Docker Engine plus Docker Compose

You do not need to install Python or OpenSSL on your host machine for this flow.

### Quick Start

From the repository root:

```bash
cd LinuxPythonBash
docker compose build
docker compose run --rm jwt-tools ./LinuxPythonBash/generate_jwt_assets.sh
```

### Important About Line Endings

Linux shell files in this repository must use `LF` line endings, not `CRLF`.

If a Windows editor converts `LinuxPythonBash/generate_jwt_assets.sh` to `CRLF`, Docker may fail with an error similar to:

```text
invalid option name ... set: pipefail
```

This repository includes `.gitattributes` to help keep Linux-facing files in the correct format:

- `*.sh` -> `LF`
- `Dockerfile` -> `LF`
- `*.yml` and `*.yaml` -> `LF`

If the error appears again, convert the affected Linux file back to `LF` and rebuild the container.

### Where The Files Go

By default, the Linux script writes files to this folder in the repository root:

```text
./jwt-keys/linux-jwt-assets
```

### Custom Output Folder

```bash
cd LinuxPythonBash
docker compose run --rm jwt-tools ./LinuxPythonBash/generate_jwt_assets.sh ./jwt-keys/my-linux-assets
```

### Optional Environment Overrides

If you want to customize the certificate subject, key size, number of valid days, or `.pfx` password:

```bash
cd LinuxPythonBash
docker compose run --rm \
  -e CERT_SUBJECT='/CN=JWTAssets' \
  -e KEY_BITS=2048 \
  -e VALID_DAYS=730 \
  -e PFX_PASSWORD='YourStrongPassword!' \
  jwt-tools ./LinuxPythonBash/generate_jwt_assets.sh ./jwt-keys/jwt-assets-linux
```

### What The Linux Flow Does

Step by step, the Docker-based flow:

1. Starts a container with OpenSSL and Python
2. Generates a new RSA private key and self-signed public certificate
3. Exports the private key as `.pfx`
4. Saves the `.pfx` password
5. Converts the `.pfx` into one-line Base64
6. Uses Python to serialize RSA private parameters into JSON
7. Creates a minified Base64 version for connector-friendly usage

### Which File Goes Where

Use these files in the following places:

- In Workfront: use `certificate_pub.crt`
- In the connector connection settings: use `rsa_params.min.b64.txt`

`certificate_pub.crt` is the public certificate file that should be uploaded to Workfront.

`rsa_params.min.b64.txt` contains the serialized private key data in a compact one-line Base64 format that is suitable for the connector connection configuration.
