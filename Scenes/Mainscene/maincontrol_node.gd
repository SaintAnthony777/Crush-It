extends Control

@onready var huffman_remake: compresseur = $"Huffman remake"
@onready var file_dialog: FileDialog = $FileDialog
@onready var compresser: Button = $Compresser
@onready var texte_de_succes: Label = $texte_de_succes
@onready var taille_du_fichier: Label = $"Taille du fichier"

var valide:=false
var source=""
var texte=" "
var can_compress=true
func _on_file_dialog_file_selected(path: String) -> void:
		source=path
		if FileAccess.file_exists(source):
			var file=FileAccess.open(source,FileAccess.READ)
			var taille:=file.get_length()/1000
			texte="Taille actuelle du fichier est de "+str(taille)+" ko"
			
			if taille>=105000000:
				valide=true 
				texte+=" le fichier est Valide, passez à la compression"
			else : 
				valide=false
				texte+=" le fichier est trop petit veuillez en entrer un supérieur à 100 Mo"
			taille_du_fichier.text=texte
			
func _process(delta: float) -> void:
	if source!="":
		taille_du_fichier.show()
	else : taille_du_fichier.hide()
	
	if valide and can_compress: compresser.disabled=false
	else : compresser.disabled=true
	
	if FileAccess.file_exists(source.get_basename()+"_DECOMPRESSED.txt"):
		texte_de_succes.show()
	else : texte_de_succes.hide()
		
func _on_ouvrir_un_fichier_pressed() -> void:
	file_dialog.show()


func _on_compresser_pressed() -> void:
	can_compress=false
	await huffman_remake.compress_file_pipeline(source,
	source.get_basename()+"_COMPRESSED.bin")
	await huffman_remake.decompress_with_header(source.get_basename()+"_COMPRESSED.bin", 
	source.get_basename()+"_DECOMPRESSED.txt")
	can_compress=true
	
