- `git pull --rebase origin <branch>`: for when you have **no local commits nor unstaged** changes


# From AI
When git pull rebases instead of merging, git refuses to run if you have any uncommitted changes to tracked files, staged or unstaged. Add this to your ~/.gitconfig:

~~~ini
[pull]
    rebase = true
[rebase]
    autoStash = false
~~~
`autoStash = false` is already the default, but setting it explicitly protects you from a project-level config turning it on. With this in place, a dirty working tree gives you something like: