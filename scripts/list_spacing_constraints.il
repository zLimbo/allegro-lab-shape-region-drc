(setq p (outfile "out/spacing_constraints.txt" "w"))
(fprintf p "%L\n" (axlCNSGetSpacing nil nil nil))
(close p)
(axlOSExit 0)
