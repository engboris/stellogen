## Processus de construction

On peut enchaîner des constellations avec l'expression `process ... end` :

```
c = process
  +n0(0).
  -n0(X) +n1(s(X)).
  -n1(X) +n2(s(X)).
end
```

Cet enchaînement part de la première constellation `+n0(0)` considérée comme
initiale. Chaque constellation suivante interagit ensuite avec le résultat
précédent. C'est comme si nous faisions le calcul suivant :

```
@+n0(0);
-n0(X) +n1(s(X)).
```

donnant

```
+n1(s(0)).
```

puis

```
@+n1(s(0));
-n1(X) +n2(s(X)).
```

donnant

```
+n2(s(s(0))).
```

> C'est ce qui correspond aux tactiques dans des assistants de preuve comme Coq
et que l'on pourrait assimiler aux programmes impératifs qui altèrent des
représentation d'état (mémoire par exemple).

> Les constructions dynamiques correspondent à la notion de "processus-preuve"
chez Boris Eng ou de "proof-trace" chez Pablo Donato. Les processus-preuves
construisent des objet-preuves (constellations).

# Arrêt de processus

Dans le résultat d'une exécution, si l'on représente les résultats par des
rayons à polarité nulle, alors les étoiles contenant des rayons polarisés
peuvent être interprétés comme des calculs non terminés qui pourraient être
effacés.

Pour cela, dans les processus de constructions, nous pouvons utiliser
l'expression spéciale `#kill` :

```
c = process
  +n0(0).
  -n0(X) +n1(s(X)).
  -n1(X) +n2(s(X)).
  -n2(X) result(X); -n2(X) +n3(X).
  #kill.
end

show-exec c.
```

Nous avons utilisé un rayon `+n3(X)` pour poursuivre des calculs
si nous souhaitons. Le résultat est stocké dans `result(X)`.
Mais si nous souhaitons seulement conserver le résultat et retirer toute
autre possibilité de calcul alors on peut utiliser `#kill`.

# Nettoyage de processus

Il arrive parfois que l'on se retrouve avec des étoiles vides `[]` dans
les processus. Il est possible de s'en débarrasser avec la commande `#clean` :

```
show-exec process
  +f(0).
  -f(X).
  #clean.
end
```
