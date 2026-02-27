extends Node

class_name NoeudHuffman

var frequence:=0
var contenu:=""
var noeud_de_gauche:NoeudHuffman=null
var noeud_de_droite:NoeudHuffman=null

func _init(freq:int,cont:String,n_gauche=null,n_droite=null) -> void:
	self.frequence=freq
	self.contenu=cont
	self.noeud_de_gauche=n_gauche
	self.noeud_de_droite=n_droite
