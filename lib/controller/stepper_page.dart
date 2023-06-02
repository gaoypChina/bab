import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Internal package
import 'package:bb/helpers/device_helper.dart';
import 'package:bb/models/brew_model.dart';
import 'package:bb/models/fermentable_model.dart';
import 'package:bb/models/hop_model.dart' as hp;
import 'package:bb/models/misc_model.dart' as mm;
import 'package:bb/models/receipt_model.dart';
import 'package:bb/utils/app_localizations.dart';
import 'package:bb/utils/constants.dart' as constants;
import 'package:bb/utils/database.dart';
import 'package:bb/utils/mash.dart' as mash;
import 'package:bb/utils/notifications.dart';
import 'package:bb/widgets/circular_timer.dart';
import 'package:bb/widgets/containers/error_container.dart';
import 'package:bb/widgets/containers/ph_container.dart';
import 'package:bb/widgets/countdown_text.dart';
import 'package:bb/widgets/dialogs/confirm_dialog.dart';
import 'package:bb/widgets/form_decoration.dart';

// External package
import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:uuid/uuid.dart';

class StepperPage extends StatefulWidget {
  final BrewModel model;
  StepperPage(this.model);

  @override
  _StepperPageState createState() => _StepperPageState();
}

class MyStep extends Step {
  int index;
  bool completed = false;
  final void Function(int index)? onStepTapped;
  final void Function(int index)? onStepCancel;
  final void Function(int index)? onStepContinue;
  MyStep({
    required this.index,
    required Widget title,
    Widget? subtitle,
    required Widget content,
    Widget? label,
    StepState state: StepState.indexed,
    bool isActive: false,
    this.onStepTapped,
    this.onStepCancel,
    this.onStepContinue
  }) : super(
    title: title,
    subtitle: subtitle,
    content: content,
    state: state,
    isActive: isActive
  );
}

class Ingredient {
  int minutes;
  Map<String, String>? map;
  Ingredient({
    required this.minutes,
    this.map
  }) {
    map ??= {};
  }
}

extension ListParsing on List {
  void set(Iterable<dynamic> iterable, BuildContext context) {
    for(dynamic item in iterable) {
      Ingredient? boil = this.cast<Ingredient?>().firstWhere((e) => e!.minutes == item.duration, orElse: () => null);
      if (boil != null) {
        boil.map![AppLocalizations.of(context)!.localizedText(item.name)] = AppLocalizations.of(context)!.weightFormat(item.amount)!;
      } else {
        add(Ingredient(
          minutes: item.duration!,
          map: { AppLocalizations.of(context)!.localizedText(item.name): AppLocalizations.of(context)!.weightFormat(item.amount)! },
        ));
      }
    }
  }
}

class _StepperPageState extends State<StepperPage> with AutomaticKeepAliveClientMixin<StepperPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  int _lastStep = 0;
  int _currentStep = 0;
  int _boilDuration = 0;

  Future<List<MyStep>>? _steps;
  late SfRadialGauge _temp;

  CountDownController _boilController = CountDownController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    return WillPopScope(
      onWillPop: () async {
        bool? exitResult = await showDialog(
          context: context,
          builder: (context) => ConfirmDialog(content: Text(AppLocalizations.of(context)!.text('stop_brewing'))),
        );
        return exitResult ?? false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: constants.FillColor,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.text('stages')),
          elevation: 0,
          foregroundColor: Theme.of(context).primaryColor,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: DeviceHelper.isLargeScreen(context) ? const Icon(Icons.close) : const BackButtonIcon(),
            onPressed:() async {
              bool? exitResult = await showDialog(
                context: context,
                builder: (context) => ConfirmDialog(content: Text(AppLocalizations.of(context)!.text('stop_brewing'))),
              );
              if (exitResult == true) {
                Navigator.pop(context);
              }
            }
          ),
        ),
        body: FutureBuilder<List<MyStep>>(
          future: _steps,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Stepper(
                currentStep: _currentStep,
                onStepCancel: () {
                  if (_currentStep > 0) {
                    try {
                      snapshot.data![_currentStep].onStepCancel?.call(_currentStep);
                      setState(() {
                        _currentStep -= 1;
                      });
                    } catch (e) {
                      _showSnackbar(e.toString());
                    }
                  }
                },
                onStepContinue: () {
                  if (_currentStep < snapshot.data!.length - 1) {
                    try {
                      snapshot.data![_currentStep].onStepContinue?.call(_currentStep);
                      setState(() {
                        _currentStep += 1;
                        if (_currentStep > _lastStep) _lastStep = _currentStep;
                      });
                    } catch (e) {
                      _showSnackbar(e.toString(), action: SnackBarAction(
                        label: 'Continuer',
                        onPressed: () {
                          setState(() {
                            _currentStep += 1;
                            if (_currentStep > _lastStep) _lastStep = _currentStep;
                          });
                        },
                      ));
                    }
                  }
                },
                onStepTapped: (int index) {
                  if (index <= _lastStep) {
                    snapshot.data![_currentStep].onStepTapped?.call(index);
                    setState(() {
                      _currentStep = index;
                    });
                  }
                },
                controlsBuilder: (BuildContext context, ControlsDetails controls) {
                  return Container(
                    margin: const EdgeInsets.only(top: 16.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints.tightFor(height: 48.0),
                      child: Row(
                        children: <Widget>[
                          ElevatedButton(
                            onPressed: controls.onStepContinue,
                            child: Text(_currentStep ==  0 ? AppLocalizations.of(context)!.text('start').toUpperCase() : localizations.continueButtonLabel),
                          ),
                          if (_currentStep != 0) TextButton(
                            onPressed: controls.onStepCancel,
                            child: Text(
                              AppLocalizations.of(context)!.text('return').toUpperCase(),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      )
                    )
                  );
                },
                steps: snapshot.data!
              );
            }
            if (snapshot.hasError) {
              return ErrorContainer(snapshot.error.toString());
            }
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor:AlwaysStoppedAnimation<Color>(Colors.black38)));
          }
        )
      )
    );
  }

  _initialize() async {
    _temp = SfRadialGauge(
        animationDuration: 3500,
        enableLoadingAnimation: true,
        axes: <RadialAxis>[
          RadialAxis(
            ranges: <GaugeRange>[
              GaugeRange(
                startValue: 0,
                endValue: 10,
                startWidth: 0.265,
                sizeUnit: GaugeSizeUnit.factor,
                endWidth: 0.265,
                color: const Color.fromRGBO(34, 195, 199, 0.75)),
              GaugeRange(
                startValue: 10,
                endValue: 30,
                startWidth: 0.265,
                sizeUnit: GaugeSizeUnit.factor,
                endWidth: 0.265,
                color: const Color.fromRGBO(123, 199, 34, 0.75)),
              GaugeRange(
                startValue: 30,
                endValue: 40,
                startWidth: 0.265,
                sizeUnit: GaugeSizeUnit.factor,
                endWidth: 0.265,
                color: const Color.fromRGBO(238, 193, 34, 0.75)),
              GaugeRange(
                startValue: 40,
                endValue: 70,
                startWidth: 0.265,
                sizeUnit: GaugeSizeUnit.factor,
                endWidth: 0.265,
                color: const Color.fromRGBO(238, 79, 34, 0.65)),
              GaugeRange(
                startValue: 70,
                endValue: 100,
                startWidth: 0.265,
                sizeUnit: GaugeSizeUnit.factor,
                endWidth: 0.265,
                color: const Color.fromRGBO(255, 0, 0, 0.65)),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                  angle: 90,
                  positionFactor: 0.35,
                  widget: Text('Temp.${AppLocalizations.of(context)!.tempMeasure}', style: const TextStyle(color: Color(0xFFF8B195), fontSize: 9))),
              const GaugeAnnotation(
                angle: 90,
                positionFactor: 0.8,
                widget: Text('  0  ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              )
            ],
            pointers: const <GaugePointer>[
              NeedlePointer(
                value: 0,
                needleStartWidth: 0,
                needleEndWidth: 3,
                knobStyle: KnobStyle(knobRadius: 0.05),
              )
            ]
          )
        ]
    );
    setState(() {
      _steps = _generate();
    });
  }

  Future<List<MyStep>> _generate() async {
    ReceiptModel receipt = widget.model.receipt!.copy();
    _boilDuration = receipt.boil!;
    List<MyStep> steps = [
      MyStep(
        index: ++_index,
        title: const Text('Début'),
        content: Container(
          alignment: Alignment.centerLeft,
          child: const Text('Démarrage du brassin')
        ),
        onStepContinue: (int index) {
          if (widget.model.status == Status.pending) {
            widget.model.status == Status.started;
            Database().update(widget.model);
          }
        },
      ),
      MyStep(
        index: ++_index,
        title: const Text('Concasser le grain'),
        content: Container(
          alignment: Alignment.centerLeft,
          child: FutureBuilder<List<FermentableModel>>(
            future: receipt.getFermentables(volume: widget.model.volume),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: snapshot.data!.map((e) {
                    return Flexible(child: Text('Concassez ${AppLocalizations.of(context)!.kiloWeightFormat(e.amount)} de «${AppLocalizations.of(context)!.localizedText(e.name)}».'));
                  }).toList()
                );
              }
              return Container();
            }
          )
        ),
      ),
      MyStep(
        index: ++_index,
        title: Text('Ajoutez ${AppLocalizations.of(context)!.litterVolumeFormat(widget.model.mash_water)} d\'eau dans votre cuve'),
        content: Container(
          alignment: Alignment.centerLeft,
          child: PHContainer(
            target: widget.model.mash_ph,
            volume: widget.model.volume,
          )
        ),
      ),
      MyStep(
        index: ++_index,
        title: Text('Mettre en chauffe votre cuve à ${AppLocalizations.of(context)!.tempFormat(50)}'),
        content: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: 140,
            height: 140,
            child: _temp,
          )
        ),
      ),
      MyStep(
        index: ++_index,
        title: const Text('Ajouter le grain'),
        content: Container(),
      )
    ];
    await _mash(receipt, steps);
    steps.add(MyStep(
      index: ++_index,
      title: Text('Rinçage des drêches avec ${AppLocalizations.of(context)!.litterVolumeFormat(widget.model.sparge_water)} d\'eau'),
      content: Container(
        alignment: Alignment.centerLeft,
        child: PHContainer(
          target: widget.model.sparge_ph,
          volume: widget.model.volume,
        )
      ),
    ));
    await _boil(receipt, steps);
    steps.add(MyStep(
      index: ++_index,
      title: const Text('Faire un whirlpool'),
      content: Container(),
    ));
    steps.add(MyStep(
      index: ++_index,
      title: const Text('Transférer le moût dans le fermenteur'),
      content: Container(),
    ));
    steps.add(MyStep(
      index: ++_index,
      title: const Text('Prendre la densité initiale'),
      content: TextField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))
        ],
        onChanged: (value) {
          widget.model.og = AppLocalizations.of(context)!.decimal(value);
          widget.model.calculate();
          Database().update(widget.model);
        },
        decoration: FormDecoration(
          icon: const Icon(Icons.first_page_outlined),
          hintText: constants.Gravity.sg == AppLocalizations.of(context)!.gravity ? '1.xxx' : null,
          labelText: AppLocalizations.of(context)!.text('oiginal_gravity'),
          border: InputBorder.none,
          fillColor: constants.FillColor, filled: true
        ),
      ),
    ));
    await receipt.getYeasts(volume: widget.model.volume).then((values) {
      steps.add(MyStep(
        index: ++_index,
        title: Text('Ajouter ${AppLocalizations.of(context)!.weightFormat(receipt.yeasts.first.amount)} de levure «${AppLocalizations.of(context)!.localizedText(receipt.yeasts.first.name)}»'),
        content: Container(),
      ));
    });
    steps.add(MyStep(
      index: ++_index,
      title: Text('Fin'),
      content: Container(
        alignment: Alignment.centerLeft,
        child: const Text('Votre brassin est prêt.')
      ),
    ));
    return steps;
  }

  _mash(ReceiptModel receipt, List<MyStep> steps) {
    for(int i = 0 ; i < receipt.mash!.length ; i++) {
      if (receipt.mash![i].type == mash.Type.infusion) {
        CountDownController controller = CountDownController();
        steps.add(MyStep(
          index: ++_index,
          title: Text('Mettre en chauffe votre cuve à ${AppLocalizations.of(context)!.tempFormat(receipt.mash![i].temperature)}'),
          content: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: 140,
              height: 140,
              child: _temp,
            )
          ),
          onStepContinue: (int index) {
            if (!controller.isStarted) {
              controller.restart(duration: receipt.mash![i].duration! * 60);
            }
          },
        ));
        steps.add(MyStep(
          index: ++_index,
          title: Text('Palier «${receipt.mash![i].name}» à ${AppLocalizations.of(context)!.tempFormat(receipt.mash![i].temperature)} pendant ${receipt.mash![i].duration} minutes'),
          content: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(8.0),
            child: CircularTimer(
              controller,
              duration: receipt.mash![i].duration! * 60,
              index: steps.length,
              onComplete: (int index) {
                Notifications().showNotification(
                  const Uuid().hashCode,
                  'Le Palier «${receipt.mash![i].name}» à ${AppLocalizations.of(context)!.tempFormat(receipt.mash![i].temperature)} est terminé.'
                );
                steps[index].completed = true;
              }
            )
          ),
          onStepContinue: (int index) {
            if (!steps[index].completed) {
              throw 'Cette étape n\'est pas terminée.';
            }
          },
        ));
      }
    }
  }

  _boil(ReceiptModel receipt, List<MyStep> steps) async {
    Map<CountDownTextController, Ingredient> ingredients = await _ingredients(receipt);
    steps.add(MyStep(
      index: ++_index,
      title: Text('Mettre en ébullition votre cuve'),
      content: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: 140,
          height: 140,
          child: _temp,
        )
      ),
      onStepContinue: (int index) {
        if (!_boilController.isStarted) {
          _boilController.restart(duration: receipt.boil! * 60);
          ingredients.forEach((key, value) {
            key.restart(Duration(minutes: _boilDuration - value.minutes));
          });
        }
      },
    ));
    steps.add(MyStep(
      index: ++_index,
      title: const Text('Commencer le houblonnage'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(8.0),
            child: CircularTimer(
              _boilController,
              duration: receipt.boil! * 60,
              index: steps.length,
              onComplete: (int index) {
                Notifications().showNotification(
                  const Uuid().hashCode,
                  'Houblonnage terminé.'
                );
                steps[index].completed = true;
              },
              onChange: (Duration duration) {
                _boilDuration = duration.inMinutes;
              }
            )
          ),
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: ingredients.entries.map((e) {
                return CountDownText(
                  duration: Duration(minutes: e.value.minutes),
                  map: e.value.map!,
                  controller: e.key,
                );
              }).toList()
            )
          )
        ]
      ),
      onStepTapped: (int index) {
        debugPrint('onStepTapped');
      },
      onStepContinue: (int index) {
        if (!steps[index].completed) {
          throw 'Cette étape n\'est pas terminée.';
        }
      },
    ));
  }

  Future<Map<CountDownTextController, Ingredient>> _ingredients(ReceiptModel receipt) async {
    List<Ingredient> list = [];
    Map<CountDownTextController, Ingredient> map = {};
    list.set(await receipt.gethops(volume: widget.model.volume, use: hp.Use.boil), context);
    list.set(await receipt.getMisc(volume: widget.model.volume, use: mm.Use.boil), context);
    for(Ingredient e in list) {
      CountDownTextController controller = CountDownTextController(); 
      map[controller] = e;
    }
    return map; 
  }

  _showSnackbar(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 10),
        action: action,
      )
    );
  }
}

