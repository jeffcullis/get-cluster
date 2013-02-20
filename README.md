`get_cluster.pl`
==============

NAME
----

**`get_cluster.pl`** -- dump a given cluster (or set of clusters) from a mask.

SYNOPSIS
--------

`get_cluster.pl --inmask <clusters.nii> --coord i,j,k[,id] [--cbox <box-width> --outijk <file.1D> --outnii <file.nii> --outxyz <file.txt>]`

DESCRIPTION
-----------

Given a NIFTI cluster mask and a point within a cluster, `get_cluster.pl` will write out the voxels in this cluster in up to three different formats.

One or more coordinates (`--coord`) and an input cluster mask (`--inmask <clusters.nii>`) must be specified. If no output file is specified (using any combination of `--outnii`, `--outxyz`, or `--outijk`) then the i,j,k cordinates and mask value are written to standard output.

The following options are available:

**`--cbox <box-width>`**
Given an i,j,k coordinate, the `cbox` value specifies how far (in each dimension) to search for neighbouring voxels in the input mask. If unspecified, the entire mask is read in, which is potentially time-consuming. **Note**: This option is ignored if more than one coordinate is specified.

**`--coord i,j,k[,maskval]`**	
One or more i,j,k coordinates with an optional mask value at the end. Coordinates/mask values are comma-separated. The mask value should be a positive integer and is used to visually distinguish between clusters. If the mask value is not specified, the default value 1 is used. Input coordinates should fall within a cluster in the input NIFTI mask. Multiple coordinates can be specified in a space-separated list.

**`--inmask <file.nii>`**
A NIFTI mask containing multiple clusters. If specified with `--outnii`, the input mask should define *all* voxels in the brain. 

**`--outijk <file.1D>`**
Write each voxel of the target cluster to the output file as "i j k mask_value". This file can then be used as input to the `3dUndump` command.

**`--outnii <file.nii>`**
Create a NIFTI file containing the target cluster. Essentially just runs the `3dUndump` command on the "outijk" data. The mask given to `--inmask` is used as the `-master` in `3dUndump`.

**`--outxyz <file.txt>`**
Writes the x y z coordinates in the target cluster to the given file. The mask value is not written. This is typically used as input to brain atlases in order to identify atlas regions covered by the target cluster.

