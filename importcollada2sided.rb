# fixcollada2sided.rb
#
#	Copyright (c) 2013 G Element Pte Ltd
#
# Parts of this program uses elements of code adapted with permission from 
# TIG's 'Fix Reversed Face Materials' tools (c).
# Those parts are highlighted using with the prefix ###TIG
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License. You
# may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License. See accompanying
# LICENSE file. 

###TIG
def process_faces(faces)
	texture_writer=Sketchup.create_texture_writer
	count=0
	percentdone=0
	faces.each{|face|
		if face.material==nil
			face.back_material=nil
		elsif face.material.texture==nil
			face.back_material=face.material
		else ### textured
			samples = []
			samples << face.vertices[0].position			 ### 0,0 | Origin
			samples << samples[0].offset(face.normal.axes.x) ### 1,0 | Offset Origin in X
			samples << samples[0].offset(face.normal.axes.y) ### 0,1 | Offset Origin in Y
			samples << samples[1].offset(face.normal.axes.y) ### 1,1 | Offset X in Y
			xyz = [];uv = []### Arrays containing 3D and UV points.
			uvh = face.get_UVHelper(true, true, texture_writer)
			samples.each { |position|
				xyz << position ### XYZ 3D coordinates
				uvq = uvh.get_front_UVQ(position) ### UV 2D coordinates
				uv << flattenUVQ(uvq)
			}
			pts = [] ### Position texture.
			(0..3).each { |i|
				pts << xyz[i]
				pts << uv[i]
			}
			mat=face.material
			face.position_material(mat, pts, false)
		end#if
		count+=1
		
		newpercent = count*100/@face_count
		if newpercent!=percentdone
			percentdone = newpercent
			Sketchup.status_text = percentdone.to_s + "%"
		end#if
	}
	return count
end#def

###TIG: Get UV coordinates from UVQ matrix.
def flattenUVQ(uvq)
	return Geom::Point3d.new(uvq.x / uvq.z, uvq.y / uvq.z, 1.0)
end

# add list of faces recursively to @faces
def traverse(m)
	m.each { |entity| 
		if entity.class==Sketchup::Face
			@faces << entity
		elsif entity.class==Sketchup::ComponentInstance
			traverse(entity.definition.entities)
		end#if
	}
end#def

# write to ruby console
def puts(value)
  SKETCHUP_CONSOLE.write("#{value}\n")
  nil
end

# main program
def main()
	if @file==nil 
		@file = UI.openpanel "Open COLLADA file", "", "*.dae"
	end#if

	if @file==nil
		return nil
	end#if

	puts("loading: "  + @file.to_s)
	model = Sketchup.active_model

	# delete default billboard person
	entities = model.active_entities
	if (entities.count>0)
		if (!entities[0].definition.description.empty?)
			entities.erase_entities entities[0] 
		end#if
	end#if

	# import model
	status = model.import @file, false
	if status==false
		UI.messagebox "Import failed for\n["+@file+"]"
		return nil
	end#if

	# add to scene. this is required in the newer sketchup
	if (Sketchup.version_number>13000000)
		cdef = model.definitions[ model.definitions.count-1 ] # add last model definition
		t = Geom::Transformation.new([0,0,0]) # position at origin
		model.entities.add_instance cdef, t
	end#if

	# collect faces to process
	@faces = []
	traverse(entities[entities.count-1].definition.entities)
	@face_count = @faces.size
	if @face_count==0 
		UI.messagebox "No geometry found"
		return nil
	end#if
	puts("# faces: " + @face_count.to_s)

	# change back material to front material and apply proper mapping
	process_faces(@faces)

	# set view, selection mode and display options
	view = model.active_view
	new_view = view.zoom_extents

	Sketchup.active_model.selection.clear
	Sketchup.send_action "selectSelectionTool:"
	model.rendering_options["EdgeDisplayMode"]=0

	@file = nil
end#def


main()

