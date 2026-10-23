Profiles are JSON maps of "menu/cname": value, applied with `.\viziotv.ps1 apply <file>`.
CNAMEs differ between firmware versions, so build them from your own TV:
`.\viziotv.ps1 settings picture`, `.\viziotv.ps1 options picture/picture_mode`, etc.
`example.json` is a starting point; delete any line whose cname does not exist on your set.
