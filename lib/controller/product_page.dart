import 'package:bb/utils/rating.dart';
import 'package:bb/widgets/dialogs/rating_dialog.dart';
import 'package:flutter/material.dart';

// Internal package
import 'package:bb/controller/basket_page.dart';
import 'package:bb/controller/forms/form_product_page.dart';
import 'package:bb/helpers/device_helper.dart';
import 'package:bb/models/product_model.dart';
import 'package:bb/utils/app_localizations.dart';
import 'package:bb/utils/basket_notifier.dart';
import 'package:bb/utils/constants.dart';
import 'package:bb/widgets/containers/image_container.dart';
import 'package:bb/widgets/containers/ratings_container.dart';
import 'package:bb/widgets/modal_bottom_sheet.dart';
import 'package:bb/widgets/paints/bezier_clipper.dart';
import 'package:bb/widgets/paints/circle_clipper.dart';
import 'package:flutter/rendering.dart';

// External package
import 'package:badges/badges.dart' as badge;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';

class ProductPage extends StatefulWidget {
  final ProductModel model;
  ProductPage(this.model);
  _ProductPageState createState() => new _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  GlobalKey _keyReviews = GlobalKey();
  final ScrollController _controller = ScrollController();
  int _baskets = 0;

  // Edition mode
  bool _features = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _controller,
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 250.0,
            foregroundColor: Colors.white,
            backgroundColor: Theme.of(context).primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 140),
              title: Text(widget.model.title!),
              background: Stack(
                children: [
                  Opacity( //semi red clippath with more height and with 0.5 opacity
                    opacity: 0.5,
                    child: ClipPath(
                      clipper: BezierClipper(), //set our custom wave clipper
                      child:Container(
                        color: Colors.black,
                        height: 200,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.only(left: 30),
                        child: ImageContainer(widget.model.image, width: null, height: null, color: Colors.transparent),
                      ),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipPath(
                              clipper: CircleClipper(), //set our custom wave clipper
                              child: Container(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: DeviceHelper.isDesktop ? 10 : 0),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (widget.model.rating > 0) Text(widget.model.rating.toStringAsPrecision(2), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                                  RatingBar.builder(
                                    initialRating: widget.model.rating,
                                    direction: Axis.horizontal,
                                    allowHalfRating: true,
                                    itemCount: 5,
                                    itemSize: 18,
                                    itemPadding: EdgeInsets.zero,
                                    itemBuilder: (context, _) => Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                    ),
                                    tapOnlyMode: true,
                                    ignoreGestures: false,
                                    onRatingUpdate: (rating) async {
                                      RenderBox box = _keyReviews.currentContext!.findRenderObject() as RenderBox;
                                      Offset position = box.localToGlobal(Offset.zero); //this is global position
                                      _controller.animateTo(
                                        position.dy,
                                        duration: Duration(seconds: 1),
                                        curve: Curves.fastOutSlowIn,
                                      );
                                      dynamic? rating = await showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return RatingDialog(
                                                Rating(
                                                  creator: currentUser!.user!.uid,
                                                  name: currentUser!.user!.displayName,
                                                  rating: 0
                                                ),
                                                maxLines: 3
                                            );
                                          }
                                      );
                                      if (rating != null) {
                                        setState(() {
                                          widget.model.ratings!.add(rating);
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 3),
                                  Text('${widget.model.notice} ${AppLocalizations.of(context)!.text('reviews')}', style: TextStyle(color: Colors.white)),
                                  const SizedBox(height: 10),
                                  Stack(
                                    children: [
                                      Image.asset('assets/images/sale.png', width: 80, color: Colors.black38),
                                      Positioned(
                                          left: 22,
                                          top: 9,
                                          child: Text('${widget.model.price!.toStringAsPrecision(3)} €', style: TextStyle(fontSize: 16, color: Colors.white))
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ]
                        ),
                      )
                    ]
                  )
                ]
              ),
            ),
            actions: <Widget> [
              badge.Badge(
                position: badge.BadgePosition.topEnd(top: 0, end: 3),
                animationDuration: Duration(milliseconds: 300),
                animationType: badge.BadgeAnimationType.slide,
                showBadge: _baskets > 0,
                badgeContent: _baskets > 0 ? Text(
                  _baskets.toString(),
                  style: TextStyle(color: Colors.white),
                ) : null,
                child: IconButton(
                  icon: Icon(Icons.shopping_cart_outlined),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) {
                      return BasketPage();
                    }));
                  },
                ),
              ),
              if (currentUser != null && currentUser!.isAdmin()) IconButton(
                icon: Icon(Icons.edit_note),
                onPressed: () {
                  _edit(widget.model);
                },
              ),
            ],
          ),
          if (widget.model.text!.isNotEmpty) SliverToBoxAdapter(
            child: ExpansionPanelList(
              elevation: 1,
              expansionCallback: (int index, bool isExpanded) {
                setState(() {
                  _features = !isExpanded;
                });
              },
              children: [
                ExpansionPanel(
                  isExpanded: _features,
                  canTapOnHeader: true,
                  headerBuilder: (context, isExpanded) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
                      title: Text(AppLocalizations.of(context)!.text('features'), style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
                    );
                  },
                  body: Container(
                    padding: EdgeInsets.only(bottom: 12, left: 12, right: 12),
                    child: MarkdownBody(data: widget.model.text!, softLineBreak: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                          .copyWith(textScaleFactor: 1.2, textAlign: WrapAlignment.start),)
                  ),
                )
              ]
            )
          ),
          if (widget.model.ratings!.isNotEmpty) SliverToBoxAdapter(
            child: RatingsContainer(widget.model)
          )
        ]
      ),
      bottomNavigationBar: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: TextButton(
          child: Text(AppLocalizations.of(context)!.text('buy_now')),
          style:  TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Theme.of(context).primaryColor,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            ModalBottomSheet.showAddToCart(context, widget.model);
          },
        ),
      ),
    );
  }

  _initialize() async {
    final basketProvider = Provider.of<BasketNotifier>(context, listen: false);
    _baskets = basketProvider.size;
    basketProvider.addListener(() {
      if (!mounted) return;
      setState(() {
        _baskets = basketProvider.size;
      });
    });
  }

  _edit(ProductModel model) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return FormProductPage(model);
    }));
  }

  _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            duration: Duration(seconds: 10)
        )
    );
  }
}