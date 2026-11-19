# Luau Runtime

**A fan-made Luau runtime and Roblox-like simulation environment.**

Luau Runtime is a project developed by Fan-Made Organization (FMO). It provides a custom simulation layer built around the Luau interpreter, with systems inspired by Roblox, including Instances, Services, Signals, Tasks, Physics, Collision, Script Management, and more.

> **Project status:** UPDATE 2.0 adds seven integrated runtime systems: Memory Manager, Event Manager, Resource Manager, Runtime Debugger, Performance Monitor, Task Queue, and Instance Manager. The expanded Super Test targets 280 automated checks. These new checks must be run locally or by CI before the release is considered verified.

---

# 🇬🇧 English

## UPDATE 2.0 — Runtime Systems Expansion

UPDATE 2.0 introduces seven new modules exposed through the shared `Game` object:

| Module | Capabilities |
|---|---|
| `MemoryManager` | Logical allocation accounting, byte limits, owners, tags, resizing, snapshots, diffs, top allocations, validation and statistics. This is runtime bookkeeping, not a reading of the Luau VM's actual heap. |
| `EventManager` | Named event channels, subscriptions, one-shot listeners, priority ordering, safe callback isolation, pause/resume, bounded history and batch publishing. |
| `ResourceManager` | Resource registration, cleanup callbacks, scopes, ownership transfer, tags, dependencies, deterministic reverse-order scope cleanup and validation. |
| `RuntimeDebugger` | Breakpoints with conditions and hit limits, watch expressions, bounded traces, value inspection and named snapshots with comparisons. |
| `PerformanceMonitor` | Bounded numeric samples, timers, callback measurement, metric summaries, performance budgets, marks and snapshot comparisons. |
| `TaskQueue` | Deferred and delayed callbacks, priority ordering, cancellation, queue limits, pause/resume, bounded history and execution budgets. |
| `InstanceManager` | Indexed Instance lookup by name/class, tags, groups, metadata, index refresh/rebuild, validation and lifecycle tracking. |

The `Game` facade exposes common entry points, and runtime statistics now include providers for the new managers. The regression suite has been expanded to **280 checks** covering normal behavior, invalid inputs, cleanup, limits, callback errors and edge cases.

**Verification status:** source changes and regression cases have been added to the `Runtime` branch. The new 282-check suite has not yet been executed in this development session; run the commands below and inspect the final report before treating UPDATE 2.0 as passing.

## Previous development — UPDATE 1.2

- Hardened Instance identity validation, parent assignment, hierarchy handling, and mutable-property cloning.
- Improved Signal connection cleanup and callback dispatch behavior.
- Added regression coverage for forged parents, circular hierarchies, deep-copy isolation, and Signal disconnection during dispatch.
- Added a Linux GitHub Actions workflow that builds the official Luau CLI and runs the integrated Super Test.
- The UPDATE 1.2 hardening suite passed 158/158 tests in GitHub Actions before merging into `Runtime`.
- UPDATE 1.3 adds `RuntimeProfiler`, integrated with `Game` and runtime statistics. It supports named timing scopes, callback measurements, bounded samples, sorted reports, and profile lifecycle controls.

## FMO Script GUI Simulator (interactive prototype)

The desktop simulator renders GUI trees created by Luau scripts using the simulated Instance
classes. It is a local compatibility/simulation tool, not a Roblox client or executor.

Install the desktop dependency on Arch Linux:

```bash
sudo pacman -S pyside6
```

Or install the Python dependency in your environment:

```bash
python3 -m pip install -r requirements.txt
```

Launch the interactive demo:

```bash
python3 gui.py
```

Launch any other compatible script:

```bash
python3 gui.py scripts/my_gui.luau
```

A GUI script creates Instances, connects callbacks to supported GUI signals, and exports its
root ScreenGui. Example:

```lua
local Game = require("../simulator/game")
local GuiBridge = require("../simulator/gui_bridge")
local Instance = Game.Instance

local screen = Instance.new("ScreenGui")
local button = Instance.new("TextButton")
button.Text = "Click me"
button.Parent = screen

button.MouseButton1Click:Connect(function()
    button.Text = "Clicked!"
end)

print("__FMO_GUI_SNAPSHOT__" .. GuiBridge.Export(screen))
```

The desktop renderer supports Frames, ScrollingFrames, TextLabels, TextButtons, TextBoxes,
ImageLabels, and ImageButtons. It also implements a growing set of visual modifiers:
UICorner, UIStroke, UIGradient, and UIScale. UIListLayout and UIGridLayout provide basic
automatic vertical/horizontal and grid placement using LayoutOrder, Padding, CellSize, and
CellPadding. ScrollingFrames use a real Qt scroll area. TextButton and ImageButton clicks,
plus TextBox editing completion, are bridged back to Luau callbacks.

Image widgets currently load local filesystem image paths. Roblox asset identifiers
(`rbxassetid://...`) are not downloaded or resolved. UIGradient color arrays and UDim-like
arrays are supported as a compatibility representation, not as complete Roblox ColorSequence,
Color3, UDim, or UDim2 implementations. Layout alignment, clipping, text scaling, nine-slice
images, rich text, and some advanced properties remain partial or unsupported.

To keep the CLI sandbox independent of host IO, each interaction currently replays the script
in a fresh Luau process, dispatches the requested event, and returns an updated snapshot.
Consequently, Lua variables and in-memory state are recreated on each event; persist state
externally if a script needs it between interactions. The simulator is a local visual
compatibility layer, not a Roblox client or executor, and does not provide complete engine
compatibility, remote asset loading, automatic file watching, or a persistent Luau VM.

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
- Runtime statistics and an integrated performance profiler.
- Integrated runtime manager.

## Runtime profiler — UPDATE 1.3

The runtime exposes a built-in profiler through `Game.RuntimeProfiler` and the
convenience methods on `Game`:

```lua
-- Measure a callback and preserve its return values.
local result = game:Profile("CustomCalculation", function(a, b)
    return a + b
end, 20, 22)

-- Or measure a manual section.
local token = game:BeginProfile("ManualSection")
-- Run the code you want to measure here.
local elapsed = game:EndProfile(token)

-- Read the report, ordered by total recorded time.
local report = game:GetProfileReport()
for _, profile in ipairs(report) do
    print(profile.Name, profile.Count, profile.Average, profile.Maximum)
end

-- Access profiler information in the general performance snapshot.
local performance = game:GetPerformanceStatistics()
local profilerStats = performance.Providers.RuntimeProfiler
```

The profiler supports bounded sample history, minimum/maximum/average/latest
timings, callback error propagation, enable/disable controls, and clearing
completed profiles. `Game:Step()` automatically records the total frame step and
its scheduler, physics, and collision phases. Measurement tokens are validated
against private timing data so editing their public fields cannot alter recorded
measurements.

**Important:** Luau Runtime is not an official Roblox runtime and does not provide complete Roblox engine compatibility. Some systems are simulations and do not reproduce real Roblox networking, physics, or execution environments.

## Requirements

You need:

1. Python 3.
2. The Luau command-line interpreter.
3. Git (only if you want to clone the repository instead of downloading the ZIP).

The GUI simulator requires PySide6. On Arch Linux install it with `sudo pacman -S pyside6`; other environments can use `python3 -m pip install -r requirements.txt`.

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

Luau Runtime uses the official Luau command-line interpreter.

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

This is the default location expected by Luau Runtime.

### Windows and macOS

Follow the official Luau build instructions:

https://github.com/luau-lang/luau

Make sure the resulting Luau executable is available at the path configured in `config.py`.

On Windows, the executable may be named `luau.exe`. If necessary, update `LUAU_EXECUTABLE` in `config.py` to point to its actual location.

## 3. Download Luau Runtime

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

If everything is configured correctly, the Luau Runtime launcher will initialize the Luau interpreter and execute the project's test script.

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
- Estadísticas del runtime y perfilador de rendimiento integrado.
- Administrador integrado del runtime.

**Importante:** Luau Runtime no es un runtime oficial de Roblox ni ofrece compatibilidad completa con su motor. Algunos sistemas son simulaciones y no reproducen completamente las redes, la física o los entornos de ejecución reales de Roblox.

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

Luau Runtime utiliza el intérprete oficial de Luau para línea de comandos.

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

Esta es la ubicación predeterminada que espera Luau Runtime.

### Windows y macOS

Sigue las instrucciones oficiales de compilación:

https://github.com/luau-lang/luau

Asegúrate de que el ejecutable de Luau esté disponible en la ruta configurada en `config.py`.

En Windows, el archivo ejecutable puede llamarse `luau.exe`. Si es necesario, modifica `LUAU_EXECUTABLE` en `config.py` para indicar su ubicación real.

## 3. Descargar Luau Runtime

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

Si todo está correctamente configurado, el lanzador de Luau Runtime inicializará el intérprete de Luau y ejecutará el script de pruebas del proyecto.

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
- Estatísticas do runtime e perfilador de desempenho integrado.
- Gerenciador integrado do runtime.

**Importante:** Luau Runtime não é um runtime oficial do Roblox e não oferece compatibilidade completa com sua engine. Alguns sistemas são simulações e não reproduzem completamente as redes, a física ou os ambientes de execução reais do Roblox.

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

Luau Runtime utiliza o interpretador oficial Luau para linha de comando.

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

Esse é o caminho padrão esperado pelo Luau Runtime.

### Windows e macOS

Siga as instruções oficiais de compilação:

https://github.com/luau-lang/luau

Certifique-se de que o executável Luau esteja disponível no caminho configurado em `config.py`.

No Windows, o executável pode se chamar `luau.exe`. Se necessário, atualize `LUAU_EXECUTABLE` em `config.py` para apontar para o local correto.

## 3. Baixar o Luau Runtime

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

Se tudo estiver configurado corretamente, o inicializador do Luau Runtime iniciará o interpretador Luau e executará o script de testes do projeto.

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

Luau Runtime — UPDATE 2.0



## Managed Garbage Collector — UPDATE 2.1

Luau Runtime now includes an explicit **managed mark-and-sweep collector** at
`Game.GarbageCollector`. It manages only values registered through this API;
it does not inspect, replace, or control the native Luau VM garbage collector.

```lua
local GC = game.GarbageCollector

-- Register managed values. Roots are the entry points of the object graph.
GC:Track("scene", sceneData, { Root = true })
GC:Track("mesh-cache", meshData)
GC:AddReference("scene", "mesh-cache")

-- Objects reachable from roots survive; unreachable objects are collected.
local ok, report = GC:Collect()
print(report.Collected, report.Retained)

-- Optional cleanup callback, invoked before the managed record is removed.
GC:Track("temporary-resource", resource, {
    Finalize = function(value)
        value:Release()
    end,
})
```

The collector supports explicit roots, object references (including cycles), safe
finalizer error handling, optional links to logical `MemoryManager` allocations,
validation, statistics, and opt-in automatic collection. Automatic collection is
disabled by default; enable it and configure its threshold/interval when the
application has finished establishing its roots and references:

```lua
GC:SetAutomaticThreshold(512)
GC:SetAutomaticInterval(2)
GC:SetAutomaticEnabled(true)
```

The automatic collector is checked during `Game:Step()`. A failed finalizer keeps
its object tracked for inspection or a later retry. The memory numbers are
runtime bookkeeping only, not measurements of the Luau VM heap.

New convenience methods are also available on `Game`:
`TrackManagedObject`, `AddManagedReference`, `SetManagedRoot`, and
`CollectGarbage`.
