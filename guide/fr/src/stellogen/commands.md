# Commandes

## Commentaires

Les commentaires commencent par `'` et sont écrits entre `'''` pour
les commentaires multi-lignes. Ils sont ignorés pendant l'exécution.

```
'this is a comment

'''
this is a
multiline comment
'''
```

## Affichage

Pour afficher des constellations, vous pouvez utiliser la commande `show`
suivit d'une constellation :

```
show +a; -a b.
```

La commande `show` n'exécute pas les constellations. Si vous voulez vraiment
exécuter la constellation et afficher son résultat, utilisez la commande
`show-exec` :

```
show-exec +a; -a b.
```

## Trace d'exécution

Il est possible de suivre pas à pas l'exécution d'une constellation :

```
ineq = +f(a); +f(b); @-f(X) -f(Y) r(X Y) | X!=Y.
'trace ineq.
```
