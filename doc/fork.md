[← Back to README](../README.md)

# Fork this repository (and keep up to date)

## 1. Fork the Repository

1. Go to the [original repository](https://github.com/sassoftware/viya4-solutions-automation) on GitHub.
2. Click the `Fork` button (top-right).
3. Choose your account or organization.

## 2. Clone Your Fork Locally

```bash
git clone https://github.com/your-username/viya4-solutions-automation.git
cd repo
```

## 3. Add the Original Repository as a Remote (Upstream)

```bash
git remote add upstream https://github.com/sassoftware/viya4-solutions-automation.git
```

Verify remotes:

```bash
git remote -v
```

You should see:

```
origin    https://github.com/your-username/viya4-solutions-automation.git (fetch)
origin    https://github.com/your-username/viya4-solutions-automation.git (push)
upstream  https://github.com/original-owner/viya4-solutions-automation.git (fetch)
upstream  https://github.com/original-owner/viya4-solutions-automation.git (push)
```

## 4. Keep Your Fork Up to Date

> **Always fetch before working on new features or creating PRs.**

### Option A: Merge the Changes (safer for most use cases)

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

### Option B: Rebase on Top of Upstream (cleaner history)

```bash
git fetch upstream
git checkout main
git rebase upstream/main
git push --force-with-lease origin main
```

## 5. Done!
You now have your fork up to date with the original repository.

---
[← Back to README](../README.md)