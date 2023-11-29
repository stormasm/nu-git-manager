use ../../src/nu-git-manager-sugar/ git [
    "gm repo get commit"
    "gm repo goto root"
    "gm repo branches"
    "gm repo is-ancestor"
    "gm repo remote list"
    "gm repo fetch branch"
    "gm repo ls"
    "gm repo branch wipe"
    "gm repo compare"
]
    let repo = get-random-test-dir --no-sanitize
    ^git checkout --orphan main
def clean [dir: path] {
    cd
    rm --recursive --force $dir
}

def commit [...messages: string]: nothing -> list<string> {
    $messages | each {|msg|
        ^git commit --allow-empty --no-gpg-sign --message $msg
            | parse --regex '\[.* (?<hash>.*)\] .*'
            | get hash.0
    }
}

    let repo = init-repo-and-cd-into
    commit "init"

    clean $repo
    let repo = init-repo-and-cd-into | path sanitize
    mkdir bar/baz
    cd bar/baz

    clean $repo
    let repo = init-repo-and-cd-into
    commit "init"

    assert equal (gm repo branches) [{branch: main, remotes: []}]
    clean $repo
    let repo = init-repo-and-cd-into
    commit "init" "c1" "c2"

    clean $repo
    let repo = init-repo-and-cd-into

    clean $repo
}

def "assert simple-git-tree-equal" [expected: list<string>, --extra-revs: list<string> = []] {
    let actual = ^git log --oneline --decorate --graph --all $extra_revs
        | lines
        | parse "* {hash} {tree}"
        | get tree
    assert equal $actual $expected
}

export def branch-fetch [] {
    let foo = init-repo-and-cd-into
    let bar = get-random-test-dir

    commit "initial commit"

    ^git clone $"file://($foo)" $bar

    ^git checkout -b foo
    commit "c1" "c2"

    do {
        cd $bar
        gm repo fetch branch $"file://($foo)" foo

        assert simple-git-tree-equal [
            "(foo) c2",
            "c1",
            "(HEAD -> main, origin/main, origin/HEAD) initial commit",
        ]
    }

    commit "c3" "c4"

    do {
        cd $bar
        gm repo fetch branch $"file://($foo)" foo

        assert simple-git-tree-equal [
            "(foo) c4",
            "c3",
            "c2",
            "c1",
            "(HEAD -> main, origin/main, origin/HEAD) initial commit",
        ]

        ^git checkout foo
    }

    commit "c5" "c6"

    do {
        cd $bar
        gm repo fetch branch $"file://($foo)" foo

        assert simple-git-tree-equal --extra-revs ["FETCH_HEAD"] [
            "c6",
            "c5",
            "(HEAD -> foo) c4",
            "c3",
            "c2",
            "c1",
            "(origin/main, origin/HEAD, main) initial commit",
        ]
    }

    do {
        cd $bar
        gm repo fetch branch $"file://($foo)" foo --strategy "rebase"

        assert simple-git-tree-equal [
            "(HEAD -> foo) c6",
            "c5",
            "c4",
            "c3",
            "c2",
            "c1",
            "(origin/main, origin/HEAD, main) initial commit",
        ]
    }

    commit "c7" "c8"

    do {
        cd $bar
        gm repo fetch branch $"file://($foo)" foo --strategy "merge"

        assert simple-git-tree-equal [
            "(HEAD -> foo) c8",
            "c7",
            "c6",
            "c5",
            "c4",
            "c3",
            "c2",
            "c1",
            "(origin/main, origin/HEAD, main) initial commit",
        ]
    }

    assert error { gm repo fetch branch $"file://($foo)" foo --strategy "" }

    clean $foo
    clean $bar
}

# ignored: interactive
def branch-interactive-delete [] {
    exit 0
}

# ignored: interactive
def branch-interactive-switch [] {
    exit 1
}

export def list [] {
    let repo = init-repo-and-cd-into | path sanitize

    let BASE_LS = {
        path: $repo,
        name: ($repo | path basename),
        staged: [],
        unstaged: [],
        untracked: [],
        last_commit: null,
        branch: main
    }

    assert equal (gm repo ls) $BASE_LS

    let initial_hash = commit "init"

    let actual = (gm repo ls | update $.last_commit.date null)
    let expected = $BASE_LS | update last_commit {date: null, title: "init", hash: $initial_hash.0}
    assert equal $actual $expected

    touch foo.txt

    let actual = (gm repo ls | update $.last_commit.date null)
    let expected = $BASE_LS
        | update last_commit {date: null, title: "init", hash: $initial_hash.0}
        | update untracked ["foo.txt"]
    assert equal $actual $expected

    ^git add foo.txt

    let actual = (gm repo ls | update $.last_commit.date null)
    let expected = $BASE_LS
        | update last_commit {date: null, title: "init", hash: $initial_hash.0}
        | update staged ["foo.txt"]
    assert equal $actual $expected

    let hash = commit "add foo.txt"

    let actual = (gm repo ls | update $.last_commit.date null)
    let expected = $BASE_LS | update last_commit {date: null, title: "add foo.txt", hash: $hash.0}
    assert equal $actual $expected

    "foo" | save --append foo.txt
    "bar" | save bar.txt
    ^git add bar.txt
    "bar" | save --append bar.txt

    let actual = (gm repo ls | update $.last_commit.date null)
    let expected = $BASE_LS
        | update last_commit {date: null, title: "add foo.txt", hash: $hash.0}
        | update unstaged ["bar.txt", "foo.txt"]
        | update staged ["bar.txt"]
    assert equal $actual $expected

    clean $repo
}

export def branch-wipe [] {
    let foo = init-repo-and-cd-into
    let bar = get-random-test-dir

    commit "initial commit"

    ^git checkout -b foo
    commit "c1" "c2" "c3"
    ^git checkout main

    ^git clone $"file://($foo)" $bar

    assert equal (^git branch | lines | str substring 2..) ["foo", "main"]

    do {
        cd $bar

        ^git branch foo origin/foo

        assert simple-git-tree-equal [
            "(origin/foo, foo) c3",
            "c2",
            "c1",
            "(HEAD -> main, origin/main, origin/HEAD) initial commit",
        ]
        gm repo branch wipe foo origin
        assert simple-git-tree-equal ["(HEAD -> main, origin/main, origin/HEAD) initial commit"]
    }

    assert equal (^git branch | lines | str substring 2..) ["main"]

    clean $foo
    clean $bar
}

export def branch-compare [] {
    let foo = init-repo-and-cd-into

    commit "initial commit"

    assert equal (gm repo compare main --head main) ""
    assert equal (gm repo compare HEAD --head HEAD) ""

    ^git checkout -b foo
    "foo" | save foo.txt
    ^git add foo.txt
    commit "c1"

    let expected = [
        "diff --git a/foo.txt b/foo.txt",
        "new file mode 100644",
        "index 0000000..1910281",
        "--- /dev/null",
        "+++ b/foo.txt",
        "@@ -0,0 +1 @@",
        "+foo",
        "\\ No newline at end of file"
        "",
    ]
    assert equal (gm repo compare main) ($expected | str join "\n")
    assert equal (gm repo compare main --head HEAD) ($expected | str join "\n")

    ^git checkout main
    "bar" | save --append foo.txt
    ^git add foo.txt
    commit "c2"

    assert equal (gm repo compare main --head foo) ($expected | str join "\n")

    clean $foo