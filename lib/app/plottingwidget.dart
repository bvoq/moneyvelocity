import 'package:flutter/material.dart';
import 'package:graphic/graphic.dart';

class PlottingWidget extends StatefulWidget {
  const PlottingWidget({required this.data, super.key});
  final List<List<Object>> data;
  @override
  State<PlottingWidget> createState() => _PlottingWidgetState();
}

class _PlottingWidgetState extends State<PlottingWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: 350,
      height: 300,
      child: Chart(
        data: widget.data,
        variables: {
          'date': Variable(
            accessor: (List list) => list[0] as String,
            scale: OrdinalScale(tickCount: 5),
          ),
          'value': Variable(
            accessor: (List list) => list[1] as num,
            scale: LinearScale(min: 0, max: 20),
          ),
          'type': Variable(
            accessor: (List list) => list[2] as String,
          ),
        },
        marks: [
          AreaMark(
            position: Varset('date') * Varset('value') / Varset('type'),
            shape: ShapeEncode(value: BasicAreaShape(smooth: true)),
            color: ColorEncode(
              variable: 'type',
              values: Defaults.colors20,
            ),
            modifiers: [StackModifier(), SymmetricModifier()],
          ),
        ],
        axes: [
          Defaults.horizontalAxis,
          Defaults.verticalAxis,
        ],
        selections: {
          'touchMove': PointSelection(
            on: {
              GestureType.scaleUpdate,
              GestureType.tapDown,
              GestureType.longPressMoveUpdate
            },
            dim: Dim.x,
            variable: 'date',
          )
        },
        tooltip: TooltipGuide(
          followPointer: [true, true],
          align: Alignment.topLeft,
          offset: const Offset(-20, -20),
          multiTuples: true,
          variables: ['type', 'value'],
        ),
        crosshair: CrosshairGuide(followPointer: [false, true]),
      ),
    );
  }
}
