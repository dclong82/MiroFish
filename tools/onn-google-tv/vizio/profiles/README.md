Profiles are JSON maps of "menu/cname": value, applied with `.\viziotv.ps1 apply <file>`.
CNAMEs differ between firmware versions, so build them from your own TV:
`.\viziotv.ps1 settings picture`, `.\viziotv.ps1 options picture/picture_mode`, etc.
`onn-W4K65M.json` was built from a real onn W4K65M-1030 on ViziOS 1.8. Run `check` first; it reports any value the TV rejects and lists the allowed ones.
