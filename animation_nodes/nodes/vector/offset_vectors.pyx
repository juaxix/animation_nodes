import bpy
from bpy.props import *
from ... math cimport Vector3, setVector3
from ... data_structures cimport FalloffEvaluator, Vector3DList
from ... base_types import AnimationNode, AutoSelectVectorization

class OffsetVectorsNode(bpy.types.Node, AnimationNode):
    bl_idname = "an_OffsetVectorsNode"
    bl_label = "Offset Vectors"

    useOffsetList = BoolProperty(default = False, update = AnimationNode.updateSockets)

    errorMessage = StringProperty()
    clampFalloff = BoolProperty(name = "Clamp Falloff", default = False)

    def create(self):
        self.newInput("Vector List", "Vector List", "vectors", dataIsModified = True)
        self.newInput("Falloff", "Falloff", "falloff")
        self.newInputGroup(self.useOffsetList,
            ("Vector", "Offset", "offset", dict(value = (0, 0, 1))),
            ("Vector List", "Offset List", "offsets"))

        self.newOutput("Vector List", "Vector List", "vectors")

        vectorization = AutoSelectVectorization()
        vectorization.input(self, "useOffsetList", [self.inputs[2]])
        self.newSocketEffect(vectorization)

    def draw(self, layout):
        if self.errorMessage != "":
            layout.label(self.errorMessage, icon = "ERROR")

    def getExecutionFunctionName(self):
        if self.useOffsetList:
            return "execute_OffsetList"
        else:
            return "execute_SameOffset"

    def execute_OffsetList(self, Vector3DList vectors, falloff, Vector3DList offsets):
        cdef:
            FalloffEvaluator evaluator = self.getFalloffEvaluator(falloff)
            Vector3* _vectors = vectors.data
            Vector3* _offsets = offsets.data
            double influence
            long i

        self.errorMessage = ""
        if len(vectors) != len(offsets):
            self.errorMessage = "Vector lists have different lengths"
            return vectors
        if evaluator is None:
            self.errorMessage = "Falloff cannot be evaluated for vectors"
            return vectors

        for i in range(len(vectors)):
            influence = evaluator.evaluate(_vectors + i, i)
            _vectors[i].x += _offsets[i].x * influence
            _vectors[i].y += _offsets[i].y * influence
            _vectors[i].z += _offsets[i].z * influence

        return vectors

    def execute_SameOffset(self, Vector3DList vectors, falloff, offset):
        cdef:
            FalloffEvaluator evaluator = self.getFalloffEvaluator(falloff)
            Vector3* _vectors = vectors.data
            Vector3 _offset
            double influence
            long i

        self.errorMessage = ""
        if evaluator is None:
            self.errorMessage = "Falloff cannot be evaluated for vectors"
            return vectors

        setVector3(&_offset, offset)

        for i in range(vectors.length):
            influence = evaluator.evaluate(_vectors + i, i)
            _vectors[i].x += _offset.x * influence
            _vectors[i].y += _offset.y * influence
            _vectors[i].z += _offset.z * influence

        return vectors

    def getFalloffEvaluator(self, falloff):
        return FalloffEvaluator.create(falloff, "Location", self.clampFalloff)
