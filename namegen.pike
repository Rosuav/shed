/*
Leading vowels: Ac Al Am Ar As At Au In I Ir Os O Ag U Eu Er Es
Trailing vowel: Ba Be Bi Ca Co Cu Ce Ga Ge He Ho Fe La Li Lu Mo Ne Ni No Pu Po Pa Ra Re Ru Se Si Na Ta Te Ti Xe
All consonants: C F Cl Cr Cs Gd Dy Cm Cf Fr Fm Sb Bk Bh B Br Cd Hf Hs H Kr Lr Pb Mg Mn Mt Md Hg Nd Np Nb N Pd P Pt K Pr Pm Rn Rh Rg Rb Rf Sm Sc Sg Sr S Tc Tb Tl Th Tm Sn W V Yb Y Zn Zr

Namegen:
* Start with a lead vowel, a trail vowel, or a one-letter consonant
* If random(10) < sizeof(name)-3, break
* Otherwise, add a continuation:
  - After a lead vowel: lead vowel, trail vowel, or one-letter consonant plus lead vowel
  - After a trail vowel: lead vowel, trail vowel, or consonant plus lead vowel
* Additional units may be constructed to take advantage of English phonograms:
  - "CHe" is a trail vowel
  - "SHe" is a trail vowel
  - "EsHf" is a lead vowel
  - "AcHs" is a lead vowel
  - "AgH" is a lead vowel
  - A one-letter consonant plus a trail vowel becomes a trail vowel.
  - A lead vowel plus a consonant becomes a lead vowel.
  - Neither of these can recurse. "AcHsH" is not valid.
  - Valid phonograms: CH, SH, GH, PH, NG, CK
*/
