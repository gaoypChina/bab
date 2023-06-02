import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Internal package
import 'package:bb/helpers/device_helper.dart';
import 'package:bb/helpers/formula_helper.dart';
import 'package:bb/utils/app_localizations.dart';
import 'package:bb/utils/constants.dart';
import 'package:bb/widgets/form_decoration.dart';

class PHContainer extends StatefulWidget {
  double? target;
  double? volume;
  PHContainer({this.target, this.volume});
  @override
  State<StatefulWidget> createState() {
    return _PHContainerState();
  }
}

class _PHContainerState extends State<PHContainer> {

  Acid? _acid;
  double? _current;
  double? _quantity;
  double? _concentration = 10;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Ajustement du pH'),
        SizedBox(
          width: DeviceHelper.isLargeScreen(context) ? 320: null,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))
                  ],
                  onChanged: (value) {
                    _current = AppLocalizations.of(context)!.volume(AppLocalizations.of(context)!.decimal(value));
                    _calculate();
                  },
                  decoration: FormDecoration(
                    labelText: 'pH actuel',
                    border: InputBorder.none,
                    fillColor: BlendColor, filled: true
                  )
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: widget.target?.toString() ?? '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))
                  ],
                  onChanged: (value) {
                    widget.target = AppLocalizations.of(context)!.volume(AppLocalizations.of(context)!.decimal(value));
                    _calculate();
                  },
                  decoration: FormDecoration(
                    labelText: 'pH cible',
                    border: InputBorder.none,
                    fillColor: BlendColor, filled: true
                  )
                )
              )
            ]
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: DeviceHelper.isLargeScreen(context) ? 320: null,
          child:Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<Acid>(
                  isExpanded: true,
                  style: DefaultTextStyle.of(context).style.copyWith(overflow: TextOverflow.ellipsis),
                  onChanged: (value) {
                    _acid = value;
                    _calculate();
                  },
                  decoration: FormDecoration(
                    labelText: AppLocalizations.of(context)!.text('acids'),
                    fillColor: BlendColor,
                    filled: true,
                  ),
                  items: Acid.values.map((Acid display) {
                    return DropdownMenuItem<Acid>(
                      value: display,
                      child: Text(AppLocalizations.of(context)!.text(display.toString().toLowerCase()))
                    );
                  }).toList()
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _concentration?.toString() ?? '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  onChanged: (value) {
                    _concentration = AppLocalizations.of(context)!.volume(AppLocalizations.of(context)!.decimal(value));
                    _calculate();
                  },
                  decoration: FormDecoration(
                    labelText: 'Concentration',
                    suffixText: '%',
                    border: InputBorder.none,
                    fillColor: BlendColor, filled: true
                  ),
                )
              )
            ]
          )
        ),
        if (_quantity != null && _quantity! > 0) SizedBox(
          width: 312,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 10.0),
            child: Text('Quantité d\'acide : ${AppLocalizations.of(context)!.numberFormat(_quantity)} ml', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
          )
        ),
      ]
    );
  }

  _calculate() async {
    setState(() {
      _quantity = FormulaHelper.pH(_current, widget.target, widget.volume, _acid, _concentration);
    });
  }
}
