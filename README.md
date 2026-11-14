# FMO Luau Runtime

**A fan-made Luau runtime and Roblox-like simulation environment.**

FMO Luau Runtime is a project developed by Fan-Made Organization (FMO). It provides a custom simulation layer built around the Luau interpreter, with systems inspired by Roblox, including Instances, Services, Signals, Tasks, Physics, Collision, Script Management, and more.

> **Project status:** Super Test completed with 149/149 tests passed.

---

# 🇬🇧 English

## Features

- Instance system and hierarchy.
- Built-in services and service management.
- Signal and event system.
- Task scheduler and RunService simulation.
- Players and CollectionService.
- Debris and HTTP services.
- TweenService.
- Script execution and module loading.
- Script lifecycle management.
- BindableEvent and BindableFunction.
- RemoteEvent and RemoteFunction simulation.
- ValueObjects.
- Object registry.
- Physics and collision simulation.
- Runtime diagnostics and error handling.
- Runtime environment and script sandbox.
- Runtime statistics.
- Integrated runtime manager.

**Important:** FMO Luau Runtime is not an official Roblox runtime and does not provide complete Roblox engine compatibility. Some systems are simulations and do not reproduce real Roblox networking, physics, or execution environments.

## Requirements

You need:

1. Python 3.
2. The Luau command-line interpreter.
3. Git (only if you want to clone the repository instead of downloading the ZIP).

No additional Python packages are currently required.

## 1. Install Python 3

Python 3 is required to run the project's launcher.

### Windows

1. Visit https://www.python.org/downloads/
2. Download the latest Python 3 installer.
3. Open the installer.
4. **Enable "Add Python to PATH".**
5. Select **Install Now**.
6. Open Command Prompt and verify:

```bash
py --version
```

You should see a Python 3 version.

If the `py` command is unavailable, try:

```bash
python --version
```

### Linux

**Arch Linux:**

```bash
sudo pacman -S python
```

**Ubuntu / Debian:**

```bash
sudo apt update
sudo apt install python3
```

**Fedora:**

```bash
sudo dnf install python3
```

Verify the installation:

```bash
python3 --version
```

### macOS

1. Visit https://www.python.org/downloads/
2. Download and install Python 3 for macOS.
3. Open Terminal and verify:

```bash
python3 --version
```

## 2. Install the Luau interpreter

FMO Luau Runtime uses the official Luau command-line interpreter.

You can find its source code here:

https://github.com/luau-lang/luau

### Linux instructions

Install the required build tools.

**Arch Linux:**

```bash
sudo pacman -S git cmake ninja clang
```

Clone the official Luau repository:

```bash
git clone https://github.com/luau-lang/luau.git
```

Enter the directory:

```bash
cd luau
```

Configure and build the command-line interpreter:

```bash
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --target Luau.Repl.CLI --config Release -j
```

After building, the interpreter should be located at:

```text
~/luau/build/luau
```

This is the default location expected by FMO Luau Runtime.

### Windows and macOS

Follow the official Luau build instructions:

https://github.com/luau-lang/luau

Make sure the resulting Luau executable is available at the path configured in `config.py`.

On Windows, the executable may be named `luau.exe`. If necessary, update `LUAU_EXECUTABLE` in `config.py` to point to its actual location.

## 3. Download FMO Luau Runtime

### Option A — Download ZIP (recommended)

1. Open the project repository on GitHub.
2. Click the green **Code** button.
3. Select **Download ZIP**.
4. Wait for the download to finish.
5. Locate the downloaded ZIP file.
6. Extract it using your operating system's archive manager.

You should now have the project folder on your computer.

### Option B — Clone with Git

```bash
git clone -b Runtime https://github.com/Fan-Made-Organization/Luau-Runtime.git
```

Enter the project directory:

```bash
cd Luau-Runtime
```

## 4. Run the project

Open a terminal inside the project directory.

The directory should contain files such as:

```text
Luau-Runtime/
├── config.py
├── main.py
├── engine/
├── simulator/
└── scripts/
    └── test.luau
```

Run the launcher:

**Linux / macOS:**

```bash
python3 main.py
```

**Windows:**

```bash
py main.py
```

If `py` is unavailable but `python` works:

```bash
python main.py
```

If everything is configured correctly, the FMO Luau Runtime launcher will initialize the Luau interpreter and execute the project's test script.

## 5. Troubleshooting

### Python command not found

Python 3 may not be installed or may not be available in your PATH.

Reinstall Python and enable the PATH option on Windows, or install it using your Linux distribution's package manager.

### Luau executable not found

Make sure the Luau interpreter was built successfully and is located where `config.py` expects it.

The default path is:

```text
~/luau/build/luau
```

You can change this path in `config.py`:

```python
LUAU_EXECUTABLE = Path.home() / "luau" / "build" / "luau"
```

### The project does not start

Check that:

- Python 3 is installed.
- The Luau interpreter works.
- You are running the command from the project directory.
- The project files were extracted correctly.

---

# 🇪🇸 Español

## Características

- Sistema de Instances y jerarquías.
- Servicios integrados y administración de servicios.
- Sistema de señales y eventos.
- Programador de tareas y simulación de RunService.
- Players y CollectionService.
- Servicios Debris y HTTP.
- TweenService.
- Ejecución de scripts y carga de módulos.
- Administración del ciclo de vida de scripts.
- BindableEvent y BindableFunction.
- Simulación de RemoteEvent y RemoteFunction.
- ValueObjects.
- Registro de objetos.
- Simulación de física y colisiones.
- Diagnósticos del runtime y manejo de errores.
- Entorno de ejecución y sandbox de scripts.
- Estadísticas del runtime.
- Administrador integrado del runtime.

**Importante:** FMO Luau Runtime no es un runtime oficial de Roblox ni ofrece compatibilidad completa con su motor. Algunos sistemas son simulaciones y no reproducen completamente las redes, la física o los entornos de ejecución reales de Roblox.

## Requisitos

Necesitas:

1. Python 3.
2. El intérprete de Luau para línea de comandos.
3. Git (solamente si quieres clonar el repositorio en lugar de descargar el ZIP).

Actualmente no se necesitan paquetes adicionales de Python.

## 1. Instalar Python 3

Python 3 es necesario para ejecutar el lanzador del proyecto.

### Windows

1. Entra en https://www.python.org/downloads/
2. Descarga el instalador de la última versión de Python 3.
3. Abre el instalador.
4. **Activa la opción "Add Python to PATH".**
5. Selecciona **Install Now**.
6. Abre CMD y comprueba la instalación:

```bash
py --version
```

Deberías ver la versión de Python 3 instalada.

Si el comando `py` no funciona, prueba:

```bash
python --version
```

### Linux

**Arch Linux:**

```bash
sudo pacman -S python
```

**Ubuntu / Debian:**

```bash
sudo apt update
sudo apt install python3
```

**Fedora:**

```bash
sudo dnf install python3
```

Comprueba la instalación:

```bash
python3 --version
```

### macOS

1. Entra en https://www.python.org/downloads/
2. Descarga e instala Python 3 para macOS.
3. Abre Terminal y comprueba:

```bash
python3 --version
```

## 2. Instalar el intérprete de Luau

FMO Luau Runtime utiliza el intérprete oficial de Luau para línea de comandos.

Puedes encontrar su código fuente aquí:

https://github.com/luau-lang/luau

### Instrucciones para Linux

Instala las herramientas necesarias para compilarlo.

**Arch Linux:**

```bash
sudo pacman -S git cmake ninja clang
```

Clona el repositorio oficial:

```bash
git clone https://github.com/luau-lang/luau.git
```

Entra en su carpeta:

```bash
cd luau
```

Configura y compila el intérprete:

```bash
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --target Luau.Repl.CLI --config Release -j
```

Después de compilarlo, el intérprete debería encontrarse en:

```text
~/luau/build/luau
```

Esta es la ubicación predeterminada que espera FMO Luau Runtime.

### Windows y macOS

Sigue las instrucciones oficiales de compilación:

https://github.com/luau-lang/luau

Asegúrate de que el ejecutable de Luau esté disponible en la ruta configurada en `config.py`.

En Windows, el archivo ejecutable puede llamarse `luau.exe`. Si es necesario, modifica `LUAU_EXECUTABLE` en `config.py` para indicar su ubicación real.

## 3. Descargar FMO Luau Runtime

### Opción A — Descargar ZIP (recomendado)

1. Abre el repositorio del proyecto en GitHub.
2. Presiona el botón verde **Code**.
3. Selecciona **Download ZIP**.
4. Espera a que termine la descarga.
5. Busca el archivo ZIP descargado.
6. Descomprímelo utilizando el administrador de archivos de tu sistema operativo.

Ahora tendrás la carpeta del proyecto en tu computadora.

### Opción B — Clonar con Git

```bash
git clone -b Runtime https://github.com/Fan-Made-Organization/Luau-Runtime.git
```

Entra en la carpeta:

```bash
cd Luau-Runtime
```

## 4. Ejecutar el proyecto

Abre una terminal dentro de la carpeta del proyecto.

Deberías encontrar archivos y carpetas como estos:

```text
Luau-Runtime/
├── config.py
├── main.py
├── engine/
├── simulator/
└── scripts/
    └── test.luau
```

Ejecuta el lanzador:

**Linux / macOS:**

```bash
python3 main.py
```

**Windows:**

```bash
py main.py
```

Si `py` no está disponible, pero `python` funciona:

```bash
python main.py
```

Si todo está correctamente configurado, el lanzador de FMO Luau Runtime inicializará el intérprete de Luau y ejecutará el script de pruebas del proyecto.

## 5. Solución de problemas

### No se encuentra el comando Python

Es posible que Python 3 no esté instalado o que no esté agregado al PATH.

Reinstala Python y activa la opción PATH en Windows, o instálalo mediante el administrador de paquetes de tu distribución Linux.

### No se encuentra el ejecutable de Luau

Comprueba que el intérprete se haya compilado correctamente y que esté en la ubicación que espera `config.py`.

La ruta predeterminada es:

```text
~/luau/build/luau
```

Puedes cambiarla en `config.py`:

```python
LUAU_EXECUTABLE = Path.home() / "luau" / "build" / "luau"
```

### El proyecto no inicia

Comprueba que:

- Python 3 esté instalado.
- El intérprete de Luau funcione.
- Estés ejecutando el comando desde la carpeta del proyecto.
- Los archivos del proyecto se hayan descomprimido correctamente.

---

# 🇧🇷 Português

## Recursos

- Sistema de Instances e hierarquias.
- Serviços integrados e gerenciamento de serviços.
- Sistema de sinais e eventos.
- Agendador de tarefas e simulação do RunService.
- Players e CollectionService.
- Serviços Debris e HTTP.
- TweenService.
- Execução de scripts e carregamento de módulos.
- Gerenciamento do ciclo de vida dos scripts.
- BindableEvent e BindableFunction.
- Simulação de RemoteEvent e RemoteFunction.
- ValueObjects.
- Registro de objetos.
- Simulação de física e colisões.
- Diagnósticos do runtime e tratamento de erros.
- Ambiente de execução e sandbox de scripts.
- Estatísticas do runtime.
- Gerenciador integrado do runtime.

**Importante:** FMO Luau Runtime não é um runtime oficial do Roblox e não oferece compatibilidade completa com sua engine. Alguns sistemas são simulações e não reproduzem completamente as redes, a física ou os ambientes de execução reais do Roblox.

## Requisitos

Você precisa de:

1. Python 3.
2. O interpretador Luau para linha de comando.
3. Git (somente se quiser clonar o repositório em vez de baixar o ZIP).

Atualmente, nenhum pacote adicional do Python é necessário.

## 1. Instalar Python 3

Python 3 é necessário para executar o inicializador do projeto.

### Windows

1. Acesse https://www.python.org/downloads/
2. Baixe o instalador da versão mais recente do Python 3.
3. Abra o instalador.
4. **Marque a opção "Add Python to PATH".**
5. Selecione **Install Now**.
6. Abra o CMD e verifique a instalação:

```bash
py --version
```

Você deverá ver a versão instalada do Python 3.

Se o comando `py` não estiver disponível, tente:

```bash
python --version
```

### Linux

**Arch Linux:**

```bash
sudo pacman -S python
```

**Ubuntu / Debian:**

```bash
sudo apt update
sudo apt install python3
```

**Fedora:**

```bash
sudo dnf install python3
```

Verifique a instalação:

```bash
python3 --version
```

### macOS

1. Acesse https://www.python.org/downloads/
2. Baixe e instale o Python 3 para macOS.
3. Abra o Terminal e verifique:

```bash
python3 --version
```

## 2. Instalar o interpretador Luau

FMO Luau Runtime utiliza o interpretador oficial Luau para linha de comando.

Você pode encontrar o código-fonte aqui:

https://github.com/luau-lang/luau

### Instruções para Linux

Instale as ferramentas necessárias para a compilação.

**Arch Linux:**

```bash
sudo pacman -S git cmake ninja clang
```

Clone o repositório oficial:

```bash
git clone https://github.com/luau-lang/luau.git
```

Entre na pasta:

```bash
cd luau
```

Configure e compile o interpretador:

```bash
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --target Luau.Repl.CLI --config Release -j
```

Após a compilação, o interpretador deverá estar localizado em:

```text
~/luau/build/luau
```

Esse é o caminho padrão esperado pelo FMO Luau Runtime.

### Windows e macOS

Siga as instruções oficiais de compilação:

https://github.com/luau-lang/luau

Certifique-se de que o executável Luau esteja disponível no caminho configurado em `config.py`.

No Windows, o executável pode se chamar `luau.exe`. Se necessário, atualize `LUAU_EXECUTABLE` em `config.py` para apontar para o local correto.

## 3. Baixar o FMO Luau Runtime

### Opção A — Baixar ZIP (recomendado)

1. Abra o repositório do projeto no GitHub.
2. Clique no botão verde **Code**.
3. Selecione **Download ZIP**.
4. Aguarde o término do download.
5. Localize o arquivo ZIP baixado.
6. Extraia o arquivo usando o gerenciador de arquivos do seu sistema operacional.

Agora você terá a pasta do projeto no seu computador.

### Opção B — Clonar com Git

```bash
git clone -b Runtime https://github.com/Fan-Made-Organization/Luau-Runtime.git
```

Entre na pasta:

```bash
cd Luau-Runtime
```

## 4. Executar o projeto

Abra um terminal dentro da pasta do projeto.

Você deverá encontrar arquivos e pastas como estes:

```text
Luau-Runtime/
├── config.py
├── main.py
├── engine/
├── simulator/
└── scripts/
    └── test.luau
```

Execute o inicializador:

**Linux / macOS:**

```bash
python3 main.py
```

**Windows:**

```bash
py main.py
```

Se `py` não estiver disponível, mas `python` funcionar:

```bash
python main.py
```

Se tudo estiver configurado corretamente, o inicializador do FMO Luau Runtime iniciará o interpretador Luau e executará o script de testes do projeto.

## 5. Solução de problemas

### Comando Python não encontrado

O Python 3 pode não estar instalado ou não estar disponível no PATH.

Reinstale o Python e marque a opção PATH no Windows, ou instale-o usando o gerenciador de pacotes da sua distribuição Linux.

### Executável Luau não encontrado

Verifique se o interpretador Luau foi compilado corretamente e está no caminho esperado pelo `config.py`.

O caminho padrão é:

```text
~/luau/build/luau
```

Você pode alterar esse caminho em `config.py`:

```python
LUAU_EXECUTABLE = Path.home() / "luau" / "build" / "luau"
```

### O projeto não inicia

Verifique se:

- Python 3 está instalado.
- O interpretador Luau está funcionando.
- Você está executando o comando dentro da pasta do projeto.
- Os arquivos do projeto foram extraídos corretamente.

---

## License

Check the repository for the project's license and usage terms.

## Developed by

**Fan-Made Organization (FMO)**

FMO Luau Runtime — Version 1.0
