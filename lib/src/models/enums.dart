/// Shape types available in the drawing engine.
enum ShapeType {
  line,
  rectangle,
  triangle,
  text,
  freehand,
  lShape,
  circle,
  tShape,
  uShape,
  boxShape,
  arrow,
  star,
  polygon,
  dimension,
}

/// Drawing modes for shapes.
enum DrawMode { stroke, fill }

/// Available tools in the drawing engine.
enum Tool { draw, measure, select, pan, eraser }

/// Resize handles on a selected shape's bounding box.
enum ResizeHandle {
  none,
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
}

/// Interaction modes when a shape is selected.
enum InteractionMode { smart, move, resize }
