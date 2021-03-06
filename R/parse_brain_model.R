#' @title Parse BrainModel from CIFTI
#' @description Extracts information about BrainModels from CIFTI file
#' @param nodeset Set of XML nodes corresponding to \code{BrainModel}
#' @param verbose print diagnostic messages
#'
#' @return List of values
#' @export
#'
#' @examples \dontrun{
#' doc = cifti_xml(fname)
#' nodes = xml_find_all(doc, "/CIFTI/Matrix/MatrixIndicesMap")
#' nodeset = xml_find_all(nodes, "./BrainModel")
#' }
#' @importFrom xml2 xml_attrs xml_find_all xml_text
parse_brain_model = function(nodeset) {
  if (is.list(nodeset) &&
      !inherits(nodeset, "xml_nodes") &&
      !inherits(nodeset, "xml_nodeset")) {
    return(lapply(nodeset, parse_brain_model))
  }
  n_nodes = length(nodeset)
  all_attrs = xml_attrs(nodeset)
  all_attrs = lapply(all_attrs, as.list)
  all_attrs = lapply(all_attrs, function(x) {
    nums = is_cifti_numeric(names(x))
    if (any(nums)) {
      x[nums] = lapply(x[nums], as.numeric)
    }
    return(x)
  })
  vert_nodes = lapply(nodeset,
                      xml_find_all,
                      xpath = "./VertexIndices")
  get_verts = function(node) {
    verts = xml_text(node)
    if (length(verts) > 0) {

      verts = lapply(verts, strsplit,
                     split = " ")
      verts = lapply(verts, `[[`, 1)
      verts = lapply(verts, as.numeric)
      if (length(verts) > 1){
        stop(paste0(
          "Multiple vertice indices ",
          "in BrainModel"))
      }
      verts = verts[[1]]
    }

    return(verts)
  }
  verts = lapply(vert_nodes, get_verts)

  vox_nodes = lapply(nodeset,
                     xml_find_all,
                     xpath = "./VoxelIndicesIJK")
  get_vox_ijks = function(node) {
    verts = xml_text(node)
    if (length(verts) > 0) {

      verts = strsplit(verts,
                       split = "\n")[[1]]
      verts = lapply(verts, function(x){
        x = strsplit(x, " ")[[1]]
        x = as.numeric(x)
      })
      
      ## === mjm 20200717
      # Originally, the code expected newlines in the XML separating
      # triples of voxel ijk indices, but many CIFTI files I've encountered
      # (ones produced by the FieldTrip MATLAB functions) don't have these 
      # newlines but rather a long string of space-delimited values of length 
      # 3 x n_vertices. Adding the below condition to accommodate this possibility.
      element_lengths = sapply(verts, length)
      if (all(element_lengths == 3))
        verts = do.call("rbind", verts)
      else if (all(element_lengths == 1))
        verts = data.frame(
          matrix(unlist(verts), ncol = 3, byrow = TRUE)
        )
      else
        stop("Unrecognized or inconsistent voxel IJK sequence")

      colnames(verts) = c("i", "j", "k")
    }
    return(verts)
  }
  vox = lapply(vox_nodes, get_vox_ijks)

  ### double_check
  n_vert = sapply(verts, length) > 0
  n_vox = lapply(vox, length) > 0

  if (!all(!(n_vox & n_vert)) ) {
    stop(paste0("Bad specification for ",
                "Vox IJK or Vertices"))
  }

  verts = mapply(function(i, l){
    attributes(i) = l
    return(i)
  }, verts, all_attrs, SIMPLIFY = FALSE)

  vox[n_vox] <- mapply(FUN = function(i,j) {
    attributes(i)$VoxelIndicesIJK <- j
    return(i)
    }, verts[n_vox], vox[n_vox])
  verts[n_vox] = vox[n_vox]

  # =====
  return(verts)
}

#' @rdname parse_brain_model
#' @param fname filename of CIFTI file
#' @export
get_brain_model = function(fname, verbose = TRUE) {
  nodes = matrix_ind_map_nodes(fname)
  nodeset = lapply(nodes, xml_find_all, xpath = "./BrainModel")
  nodeset = keep_sub_nodeset(nodeset)
  if (verbose) {
    message("Parsing Brain Model Data")
  }
  parse_brain_model(nodeset)
}
