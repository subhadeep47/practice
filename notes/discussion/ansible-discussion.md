# Ansible Comprehensive Master Guide & Reference Manual

This master document captures every detail, keyword, block construct, module specification, custom execution environment configuration, and AWX/Tower variable resolution workflow discussed in our session.

---

## 1. Ansible Playbook Blocks & Exception Handling (`block`, `rescue`, `always`)

In Ansible, a **`block`** is a logical grouping of tasks. Its primary purpose is to allow **try/catch/finally-style error handling** within a playbook, as well as applying common attributes (like `when`, `become`, or `tags`) to multiple tasks at once.

### A. Core Block Sections
*   **`block`**: The primary tasks that you want to execute.
*   **`rescue`**: Tasks that run *only* if one or more tasks in the `block` section fail.
*   **`always`**: Tasks that run *no matter what*—whether the `block` succeeded or failed.

### B. Detailed Example: Error Handling with Blocks
```yaml
- name: Deploy application and handle errors safely
  hosts: webservers
  become: true
  tasks:
    - name: Application deployment block
      block:
        - name: Stop target service
          ansible.builtin.service:
            name: nginx
            state: stopped

        - name: Deploy new binary
          ansible.builtin.copy:
            src: /local/app/v2/binary
            dest: /var/www/app/binary

        - name: Start target service
          ansible.builtin.service:
            name: nginx
            state: started

      rescue:
        - name: Rollback to previous version upon failure
          ansible.builtin.copy:
            src: /local/app/v1/binary
            dest: /var/www/app/binary

        - name: Restart service after rollback
          ansible.builtin.service:
            name: nginx
            state: restarted

      always:
        - name: Log deployment execution status
          ansible.builtin.debug:
            msg: "Deployment sequence completed for host."
```

---

## 2. Complete Inventory of All Ansible Playbook Keywords

Ansible keywords are grouped by the level at which they are declared: **Play-level**, **Task-level**, and **Block-level**.

### A. Play-Level Keywords (The Outer Structure)
These keywords govern how an entire play targets and executes actions on infrastructure.

| Keyword | Detailed Purpose / Function |
| :--- | :--- |
| **`hosts`** | Defines which hosts or inventory groups the play targets (e.g., `webservers`, `all`). |
| **`name`** | A descriptive string label for the play, visible in CLI execution logs. |
| **`become`** | Boolean (`true`/`false`) to enable privilege escalation (e.g., run as root via sudo). |
| **`become_method`** | The privilege escalation method to use (e.g., `sudo`, `su`, `doas`, `pbrun`). |
| **`become_user`** | The user to switch to during privilege escalation (defaults to `root`). |
| **`become_flags`** | Additional flags or arguments to pass to the privilege escalation command. |
| **`gather_facts`** | Boolean (`yes`/`no`) to automatically collect target system facts (OS, IP, memory). |
| **`gather_subset`** | Restricts which subsets of facts are gathered (e.g., `min`, `network`, `hardware`) to speed up runs. |
| **`gather_timeout`** | Maximum duration (in seconds) allowed for gathering facts before timing out. |
| **`vars`** | A dictionary/map of variables scoped and available exclusively to this play. |
| **`vars_files`** | A list of external YAML file paths containing variables to load into the play. |
| **`vars_prompt`** | Prompts the user interactively in the terminal for sensitive variable values before execution. |
| **`roles`** | A list of structured Ansible roles to execute sequentially before the play's tasks. |
| **`pre_tasks`** | A list of tasks to execute *before* any roles are run. |
| **`tasks`** | The main sequential list of tasks executed after roles. |
| **`post_tasks`** | A list of tasks to execute *after* all main tasks and roles have finished. |
| **`handlers`** | Special tasks triggered only via the `notify` keyword. |
| **`strategy`** | The execution model strategy (e.g., `linear` [default, locks steps across hosts], `free` [hosts run independently as fast as possible]). |
| **`serial`** | Defines rolling update batch sizes (e.g., `1`, `10%`, `[1, 5, 10]` rolling upgrades). |
| **`max_fail_percentage`** | Aborts the run if a specified percentage of hosts fail during execution. |
| **`order`** | Controls host execution sorting order (`inventory`, `sorted`, `reverse_sorted`, `shuffle`). |
| **`connection`** | Connection plugin type to use (`ssh`, `local`, `docker`, `winrm`). |
| **`port`** | Overrides the default remote connection port (e.g., custom SSH port). |
| **`remote_user`** | The system user account used to log into remote target nodes. |
| **`collections`** | List of collection namespaces searched automatically for modules and roles. |
| **`force_handlers`** | Forces handlers to run even if a task fails midway through the play. |
| **`any_errors_fatal`** | If `true`, a failure on any single host instantly kills execution across all hosts. |

### B. Task-Level Keywords & Directives
These keywords define individual operational instructions within a play or block.

| Keyword | Detailed Purpose / Function |
| :--- | :--- |
| **`name`** | Human-readable title for the task (critical for tracking execution output logs). |
| **`action`** | Alternative syntax for defining a module and its parameters (`action: apt name=nginx state=present`). |
| **`local_action`** | Executes the module locally on the control machine instead of remote hosts. |
| **`register`** | Captures standard output, error, and return codes of a task into a custom variable name. |
| **`when`** | Evaluates a conditional statement; skips the task if the statement yields `false`. |
| **`loop`** | Iterates a task over an array/list of items (accessed inside via `{{ item }}`). |
| **`with_<lookup>`** | Legacy loop formats (`with_items`, `with_fileglob`, `with_dict`) largely superseded by `loop`. |
| **`loop_control`** | Modifies loop behaviors (e.g., `index_var`, `loop_var`, `paused`, `extended`). |
| **`notify`** | Triggers a named handler if and only if the task reports a `changed` state. |
| **`ignore_errors`** | Boolean (`true`/`false`) allowing play execution to proceed even if the task fails. |
| **`ignore_unreachable`** | Bypasses host unreachability errors and continues execution on other live hosts. |
| **`failed_when`** | Customizes what logical condition triggers a task failure based on module returns. |
| **`changed_when`** | Customizes what logical condition classifies a task output state as `changed`. |
| **`delegate_to`** | Offloads a specific task execution onto a different host (e.g., load balancer or `localhost`). |
| **`delegate_facts`** | When delegating, determines whether facts gathered belong to the target or delegate host. |
| **`run_once`** | Bypasses the host loop, running the task exclusively on the first available host in the batch. |
| **`throttle`** | Limits the maximum number of parallel concurrent host executions for this specific task. |
| **`timeout`** | Time limit in seconds for a task action; aborts if execution exceeds this limit. |
| **`until`** | Implements a retry-loop structure, repeating the task until a condition evaluates to `true`. |
| **`retries`** | Maximum number of attempts allowed when paired with the `until` keyword. |
| **`delay`** | Pause duration (in seconds) between retry attempts when using `until`. |
| **`tags`** | String labels assigned to tasks to filter executions using `--tags` or `--skip-tags`. |
| **`environment`** | Dictionary injecting custom environment variables into the task's execution environment. |
| **`check_mode`** | Forces a task to run in dry-run mode (`true`) or standard execution mode (`false`). |
| **`diff`** | Toggles whether Ansible should display text-file diff changes during template/copy operations. |

---

## 3. Detailed Guide to Essential Ansible Modules & When to Use Them

### A. System & OS Administration Modules
*   **`ansible.builtin.package`**: Universal wrapper module that abstracts system package managers. **When to use:** When writing cross-distribution roles where targets might run Ubuntu (`apt`), RHEL (`dnf`), or Alpine (`apk`).
*   **`ansible.builtin.apt`**: Manages packages specifically for Debian/Ubuntu systems. **When to use:** When you need explicit control over Debian package repositories, `.deb` files, or debconf settings.
*   **`ansible.builtin.dnf` / `yum`**: Manages packages on Red Hat Enterprise Linux, CentOS, and Fedora systems. **When to use:** When working exclusively with RedHat family package setups and repository flags.
*   **`ansible.builtin.service`**: Controls service states via systemd, sysvinit, or upstart. **When to use:** For managing long-running background daemons like databases, web servers, or custom software agents.
*   **`ansible.builtin.systemd`**: Fine-tuned control specifically for systemd service managers. **When to use:** When you need advanced systemd actions like reloading the daemon configuration tree or unmasking blocked services.

### B. File, Storage & Template Modules
*   **`ansible.builtin.file`**: Manages file states, directories, links, and access properties. **When to use:** To set up folder directory trees, assign permission masks (`0755`), clean up old paths, or make symlinks.
*   **`ansible.builtin.copy`**: Transfers static files from the local control node to target machines. **When to use:** To push static assets, pre-written binary tools, or strict configuration files that require no variable substitution.
*   **`ansible.builtin.template`**: Compiles local Jinja2 template files (`.j2`) into fully rendered configuration files on targets. **When to use:** When configuration files require dynamic injection of host facts, environment parameters, or play variables (e.g., Nginx, Apache, or database config files).
*   **`ansible.builtin.lineinfile`**: Ensures a specific line exists (or matches a regex pattern) inside a text file. **When to use:** For quick tweaks to existing text configuration files (like appending a line to `/etc/hosts` or modifying `/etc/ssh/sshd_config`) without managing the entire file.
*   **`ansible.builtin.archive` / `unarchive`**: Packs or extracts compressed tar/zip files. **When to use:** To unpack downloaded application tarballs or zip distributions on target systems.

### C. Identity, User & Security Modules
*   **`ansible.builtin.user`**: Manages user accounts, UID allocation, shell paths, and groups. **When to use:** For provisioning system application accounts or administrative users across infrastructure nodes.
*   **`ansible.builtin.group`**: Manages Linux/Unix system user groups. **When to use:** To establish specific group permissions for collaborative application directories.
*   **`ansible.posix.authorized_key`**: Manages public SSH keys for user accounts. **When to use:** To securely inject SSH keys into `~/.ssh/authorized_keys` for passwordless server administration.

### D. Command Execution Modules (Escape Hatches)
*   **`ansible.builtin.command`**: Executes a raw executable binary directly on remote nodes. **When to use:** When no native module exists to perform an action. *(Does not support shell variables or pipes).*
*   **`ansible.builtin.shell`**: Executes command strings through a target shell environment (`/bin/sh`). **When to use:** When you explicitly require shell piping (`grep`, `awk`, `\|`), redirection (`>`), or environment path lookups.
*   **`ansible.builtin.script`**: Copies a local shell/Python script to the remote server and runs it immediately. **When to use:** When you have an existing robust multi-step bash/python diagnostic script locally that you want to execute remotely without permanent file deployment.

---

## 4. How to Create a Custom Ansible Execution Environment (EE)

An Execution Environment packages Ansible collections, Python dependencies, system dependencies, and runtime binaries into a single container image.

### Step-by-Step Build Workflow
1. **Install Ansible Builder:**
   ```bash
   pip install ansible-builder
   ```
2. **Create Project Layout:**
   Create a directory containing `execution-environment.yml`, `requirements.yml`, `requirements.txt`, and `bindeps.txt`.
3. **Configure `execution-environment.yml`:**
   ```yaml
   ---
   version: 3

   images:
     base_image:
       name: quay.io/ansible/ansible-runner:latest

   dependencies:
     ansible_core:
       package_pip: ansible-core>=2.15.0
     ansible_collection:
       - name: community.general
       - name: amazon.aws
     requirements:
       - requirements.txt
     system:
       - bindeps.txt

   additional_build_steps:
     prepend_base:
       - RUN yum update -y && yum clean all
     append_final:
       - RUN echo "Custom execution environment build complete!"
   ```
4. **Build the Container Image:**
   ```bash
   ansible-builder build --tag my-custom-ee:1.0.0 --verbose
   ```
5. **Usage:** Push the image to a container registry (e.g., Quay.io/Docker Hub) to reference it directly in Ansible Automation Controller / AWX Job Templates or run locally via Ansible Navigator.

---

## 5. AWX / Ansible Tower Variable Resolution (`group_vars` & `host_vars`)

AWX natively adheres to Ansible's core variable resolution logic using `ansible-runner`.

### A. How Variables are Fetched
* **Inventory Proximity:** Ansible automatically scans for `group_vars/` and `host_vars/` directories residing in the **exact same directory level** as the inventory file passed via `-i`.
* **Repository Synchronization:** When AWX syncs a project repository, it looks up inventories through defined paths. If your inventory file is located at `inventories/production/hosts.yml`, AWX looks right beside it at `inventories/production/group_vars/`.

### B. Recommended Project Layout for AWX
```text
my-ansible-project/
├── ansible.cfg
├── playbooks/
│   └── site.yml
└── inventories/
    └── production/
        ├── hosts.yml          <-- Inventory target selected in AWX
        └── group_vars/
            ├── all.yml        <-- Scanned automatically for all hosts
            └── webservers.yml <-- Scanned automatically for the webservers group
```