# GitHub SSH Authentication Setup

This guide covers using SSH keys to authenticate Git operations with GitHub from Linux shells.

## How keys work across machines and sessions

An SSH key pair belongs on the machine that uses it. Register each machine's public key with the same GitHub account; GitHub permits multiple account SSH keys. Prefer a unique key per machine and do not copy private keys between VMs. Remove a machine's public key from GitHub when that machine is retired.

Shell sessions on the same machine can use the same key files. A passphrase-protected key may need to be added to an SSH agent in each session unless the environment already shares an agent.

## Create a key

Choose a unique filename if the suggested path already exists. Generate an Ed25519 key and enter a strong passphrase when prompted:

```bash
install -d -m 700 ~/.ssh
ssh-keygen -t ed25519 -a 64 -C "your-github-email" -f ~/.ssh/id_ed25519_github
```

Do not put the passphrase on the command line or share the private key file. The private key has no `.pub` suffix; only the `.pub` file is registered with GitHub.

## Register the public key with GitHub

Display the public key, then add it in **GitHub → Settings → SSH and GPG keys → New SSH key**. Select an authentication key and give it a descriptive title for the machine.

```bash
cat ~/.ssh/id_ed25519_github.pub
```

The public key is safe to register with GitHub. Never upload or send the private key.

## Select the key and load it into the agent

Add or update the `github.com` block in `~/.ssh/config`:

```sshconfig
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
    AddKeysToAgent yes
```

Protect the SSH directory and config:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/id_ed25519_github
chmod 644 ~/.ssh/id_ed25519_github.pub
```

If the current shell has no SSH agent, start one and add the key. The agent keeps the unlocked key available for that session:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_github
```

Enter the passphrase at the prompt. Do not save it in shell history, a script, or a Git remote URL.

## Test and use the key

Test authentication:

```bash
ssh -T git@github.com
```

GitHub should identify the account and indicate that it does not provide shell access. For an existing repository, switch its `origin` to SSH and push:

```bash
git remote set-url origin git@github.com:OWNER/REPOSITORY.git
git push origin BRANCH
```

Replace `OWNER`, `REPOSITORY`, and `BRANCH` with the actual repository details. The GitHub account must have access to that repository.

## Troubleshooting

- `Permission denied (publickey)`: confirm the `.pub` key was added to the intended GitHub account, the private key is present on this machine, and `~/.ssh/config` selects the correct key.
- `Could not open a connection to your authentication agent`: start an agent in the current shell and run `ssh-add` as shown above.
- For multiple GitHub accounts on one machine, use distinct key files and separate SSH host aliases; point each repository remote at the appropriate alias.
- When connecting to GitHub from a new machine, verify GitHub's published SSH host-key fingerprint before accepting a first-time host key prompt.
