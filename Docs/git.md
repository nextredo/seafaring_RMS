# Git configuration woes

- This document helps fix git troubles like remembering passwords or using more than 1 account

## Important Note

- [Git Credential Manager (GCM)](https://github.com/git-ecosystem/git-credential-manager)
- Super useful for GitHub access since they stopped HTTPS with normal password use

## Multiple GitHub accounts (Windows)

- [This article](https://medium.com/@pinglinh/how-to-have-2-github-accounts-on-one-machine-windows-69b5b4c5b14e)
  - Generating GitHub SSH key + configuring local git for it
  - Do it all in git bash
- SSH agent
  - Run the following two lines after keygen in the article
  - Start agent: `eval $(ssh-agent)`
  - Add key: `ssh-add ~/.ssh/<private_key_file>`
- git config
  - In the `.git` folder for this repo
  - add the line `sshCommand = ssh -i ~/.ssh/<private_key_file>`
  - Change the remote from the top to the bottom one:

```conf
[remote "origin"]
    url = https://github.com/<github_username>/seafaring_RMS.git
    fetch = +refs/heads/*:refs/remotes/origin/*
[remote "origin"]
    url = git@github.com:<github_username>/seafaring_RMS.git
    fetch = +refs/heads/*:refs/remotes/origin/*
```

## Force Windows to remember SSH key password

- [This article](https://stackoverflow.com/questions/8518515/how-to-make-windows-remember-my-passphrase-key)
  - Enable OpenSH Auth Agent service
  - Add key to agent
  - Add git environment var
  - Config git
