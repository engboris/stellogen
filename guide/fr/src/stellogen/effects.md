# Effets réactifs

Stellogen utilise des "effets réactifs" qui sont déclenchés lors de
l'interaction entre des rayons utilisant des symboles de têtes spéciaux.

## Print

Pour l'affichage, il faut une interaction entre deux rayons `%print`.
L'interaction génère une substitution définissant le rayon à afficher :

```
run +%print(X); -%print("hello world\n").
```

La commande ci-dessus affiche `hello world` puis un saut à la ligne.
