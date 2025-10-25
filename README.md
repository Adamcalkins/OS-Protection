# 🧩 OSO – Automatic Startup Control Script

A modular PowerShell-based framework designed to **analyze, monitor, and control automatic startup entries in Windows systems**.  
OSO (Operating System Observer) provides a dynamic, extensible solution for detecting unauthorized autostart programs, verifying digital signatures, generating detailed reports, and automatically quarantining suspicious entries.

---

## 🚀 Features

- **Dynamic module loading** – automatically detects and loads all `OSO-*` modules from the `/Modules` directory.
- **Full autostart enumeration** – scans the Windows Registry, Startup folders, and Task Scheduler.
- **Baseline Whitelist** – allows saving trusted startup entries for future comparison.
- **Digital signature verification** – checks executables for valid, missing, or invalid signatures.
- **Comprehensive reporting** – exports results to CSV (and optionally HTML/JSON in future versions).
- **Windows Event Viewer logging** – writes security-related events to the Application log.
- **Automatic blocking & quarantine** – removes registry entries or moves files to quarantine.
- **Modular design** – new modules can be added easily without modifying the main menu.

---

## 🧱 Project Structure

```text
├── Main_Menu.ps1                 # Core script that dynamically loads all modules
├── Modules/
│   ├── OSO-Enumerate.ps1         # Scanning engine – collects autostart data
│   ├── OSO-Whitelist.ps1         # Creates baseline whitelist of trusted entries
│   ├── OSO-Analyze.ps1           # Compares current state vs whitelist and checks signatures
│   ├── OSO-Report.ps1            # Generates full CSV reports for user
│   ├── OSO-Notify.ps1            # Logs results into Windows Event Viewer
│   ├── OSO-Block.ps1             # Blocks and quarantines suspicious entries
│   └── (future modules…)         # Placeholder for future expansion
└── Whitelist_Base.csv            # Generated whitelist after initial scan

---

## ⚙️ Module Overview

### **Main_Menu.ps1**
A dynamic loader and interface controller for the OSO toolkit.  
Automatically scans the `/Modules` directory for scripts prefixed with `OSO-`, imports them, and builds an interactive menu. Each module exposes a `Start-<ModuleName>` function that can be executed directly from the menu.  
This approach allows seamless scalability — new modules appear automatically without manual modification.

---

### **OSO-Enumerate.ps1**
A “clean scanning engine” that gathers all Windows autostart entries and returns them as an array of PowerShell objects.  
It inspects the Registry (Run/RunOnce keys, Policies), Startup folders (resolving `.lnk` shortcuts), and the Task Scheduler (logon/startup triggers).  
Each entry includes location, path, name, value, and type.  
Optionally runs in silent mode with `-Silent`, suppressing console output.

---

### **OSO-Whitelist.ps1**
Creates a **baseline whitelist** of trusted startup entries, serving as a reference for later analyses.  
After performing a full system scan using `Start-Enumerate`, it exports results to `Whitelist_Base.csv`.  
The whitelist ensures future scans only highlight new or modified entries.

---

### **OSO-Analyze.ps1**
Compares the current autostart configuration against the baseline whitelist.  
Detects newly added or changed entries, verifies their digital signatures (`Get-AuthenticodeSignature`), and classifies results as **Valid**, **Unsigned**, or **Invalid**.  
Outputs a table and returns structured analysis results for further processing by other modules.

---

### **OSO-Report.ps1**
Generates a **detailed user report** containing all detected autostart entries.  
Displays summary statistics (count by location) and saves a full CSV report to the user’s Desktop, with automatic timestamping.  
Optionally prompts to open the generated file.

---

### **OSO-Notify.ps1**
Logs the results of `Start-Analyze` into the **Windows Event Viewer (Application Log)**.  
Uses the event source `OSO-SecurityMonitor`.  
Valid entries are logged as *Information* (Event ID 4100), while unsigned or invalid entries appear as *Warnings* (Event ID 4200).  
Returns a list of suspicious entries for further review or blocking.

---

### **OSO-Block.ps1**
Automatically blocks suspicious autostart entries identified by `Start-Notify`.  
Registry entries are deleted via `Remove-ItemProperty`, and file-based entries are moved to a dedicated quarantine folder (`/Quarantine_Files`).  
All blocked items are recorded in `quarantine.csv` for auditing and potential restoration.

---

## 🪟 Requirements

- **Windows 10 / 11**
- **PowerShell 5.1 or later** (PowerShell 7+ recommended)
- Administrator privileges (for registry access and Event Viewer logging)
- Execution Policy: `RemoteSigned` or `Bypass` (for local module loading)

---
