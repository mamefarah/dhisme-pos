import 'package:flutter/material.dart';
import '../models/workflow_guide.dart';

const _allRoles = {'owner', 'manager', 'seller'};
const _ownerManager = {'owner', 'manager'};

const workflowGuides = <WorkflowGuide>[
  WorkflowGuide(
    id: 'sell',
    icon: Icons.point_of_sale_outlined,
    title: GuideText('Sida loo iibiyo alaab', 'Sell an item'),
    summary: GuideText('Laga bilaabo raadinta alaabta ilaa rasiidka', 'From finding the product to sharing the receipt'),
    sequences: [
      GuideSequence(
        id: 'sell',
        title: GuideText('Iib', 'Sale'),
        roles: _allRoles,
        steps: [
          GuideStep(
            icon: Icons.search,
            title: GuideText('Raadi alaabta', 'Find the product'),
            body: GuideText('Magaca ku raadi ama ka dooro liiska alaabta.', 'Search by name or pick the product from the list.'),
          ),
          GuideStep(
            icon: Icons.pin_outlined,
            title: GuideText('Geli tirada', 'Enter the quantity'),
            body: GuideText('Ku dar tirada uu macmiilku rabo gaarigaaga.', 'Add the amount the customer wants to the cart.'),
          ),
          GuideStep(
            icon: Icons.fact_check_outlined,
            title: GuideText('Hubi kaydka iyo qiimaha', 'Check stock and price'),
            body: GuideText(
              'Hubi in alaabtu ku jirto kaydka, iyo in qiimaha iyo wadarta gaariga ay sax yihiin.',
              'Make sure the item is in stock and that the price and cart total are correct.',
            ),
          ),
          GuideStep(
            icon: Icons.account_balance_wallet_outlined,
            title: GuideText('Dooro qaabka bixinta', 'Choose how the customer pays'),
            body: GuideText(
              'Lacag caddaan, bangi, lacag mobile, ama isku dhafan (u qaybi lacagta caddaanka, bangiga iyo mobile-ka). Haddii macmiilku dambe bixinayo, dooro codsi deyn.',
              'Cash, bank, mobile money, or mixed (split between cash, bank and mobile money). If the customer will pay later, choose a credit request instead.',
            ),
          ),
          GuideStep(
            icon: Icons.check_circle_outline,
            title: GuideText('Dhammee iibka', 'Complete the sale'),
            body: GuideText(
              'Taabo Dhammee. Iibka caddaanka, bangiga, mobile-ka iyo isku dhafan isla markaas ayaa la diiwaangeliyaa.',
              'Tap Complete. Cash, bank, mobile money and mixed sales are recorded right away.',
            ),
          ),
          GuideStep(
            icon: Icons.share_outlined,
            title: GuideText('La wadaag rasiidka', 'Share the receipt'),
            body: GuideText('Rasiidka ayaa furmaya. Ku wadaag PDF ama daabac.', 'The receipt opens after the sale. Share it as a PDF or print it.'),
          ),
        ],
      ),
    ],
  ),
  WorkflowGuide(
    id: 'purchase',
    icon: Icons.shopping_cart_outlined,
    title: GuideText('Iibso oo kaydi alaab', 'Buy and replenish stock'),
    summary: GuideText('Diiwaangeli iibsiga alaab-qeybiyaha', 'Record a supplier purchase'),
    sequences: [
      GuideSequence(
        id: 'purchase',
        title: GuideText('Iibsi', 'Purchase'),
        roles: _ownerManager,
        steps: [
          GuideStep(
            icon: Icons.inventory_2_outlined,
            title: GuideText('Fur Iibsiyada', 'Open Purchases'),
            body: GuideText('Shaashadda Alaab, taabo saddexda dhibcood (⋮) kuna dooro Iibsiyada.', 'On the Products screen, tap the three dots (⋮) and choose Purchases.'),
            actor: GuideActor.ownerOrManager,
          ),
          GuideStep(
            icon: Icons.local_shipping_outlined,
            title: GuideText('Dooro alaab-qeybiyaha iyo alaabta', 'Pick the supplier and items'),
            body: GuideText('Dooro alaab-qeybiyaha, kadibna ku dar alaab kasta iyo tirada iyo qiimaha iibsiga.', 'Choose the supplier, then add each product with its quantity and cost.'),
            actor: GuideActor.ownerOrManager,
          ),
          GuideStep(
            icon: Icons.payments_outlined,
            title: GuideText('Geli lacagta la bixiyay', 'Enter what you paid'),
            body: GuideText(
              'Geli lacagta hadda la bixiyay. Inta hartay waxay noqonaysaa deyn alaab-qeybiyaha lagu leeyahay. Haddii wax hadhaan, alaab-qeybiye ayaa loo baahan yahay. Ma bixin kartid wadarta ka badan.',
              'Enter the amount paid now. Anything left is kept as a debt to the supplier. A supplier is required when part is unpaid, and you cannot pay more than the total.',
            ),
            actor: GuideActor.ownerOrManager,
          ),
          GuideStep(
            icon: Icons.save_outlined,
            title: GuideText('Kaydi iibsiga', 'Save the purchase'),
            body: GuideText('App-ku wuxuu hubiyaa lambarada ka hor intaan la kaydin.', 'The app checks the amounts before saving.'),
            actor: GuideActor.ownerOrManager,
          ),
          GuideStep(
            icon: Icons.trending_up,
            title: GuideText('Kaydku wuu kordhayaa', 'Stock goes up'),
            body: GuideText(
              'App-ku wuxuu kordhiyaa kaydka alaab kasta, lacagta aan la bixinna wuxuu u diiwaangeliyaa deyn. Kaydka gacanta ha ku bedelin.',
              'The app increases stock for each product and records any unpaid amount as debt. You do not change stock by hand.',
            ),
            actor: GuideActor.app,
          ),
        ],
      ),
    ],
  ),
  WorkflowGuide(
    id: 'credit',
    icon: Icons.handshake_outlined,
    title: GuideText('Iib deyn ah', 'Sell on credit'),
    summary: GuideText('Codsi, ansixinta milkiilaha iyo diiwaangelinta deynta', 'Request, owner decision, and when debt is recorded'),
    sequences: [
      GuideSequence(
        id: 'credit',
        title: GuideText('Iib deyn ah', 'Credit sale'),
        roles: _allRoles,
        steps: [
          GuideStep(
            icon: Icons.person_search_outlined,
            title: GuideText('Dooro macmiilka iyo alaabta', 'Pick the customer and items'),
            body: GuideText('Ku dar alaabta sida caadiga ah, kadibna dooro macmiilka.', 'Add the items as usual, then choose the customer.'),
          ),
          GuideStep(
            icon: Icons.request_quote_outlined,
            title: GuideText('Dooro codsi deyn', 'Choose credit request'),
            body: GuideText('Qaabka bixinta ku dooro codsi deyn.', 'Set the payment mode to credit request.'),
          ),
          GuideStep(
            icon: Icons.send_outlined,
            title: GuideText('U dir Ansixin', 'Send for Approval'),
            body: GuideText(
              'Taabo U dir Ansixin. Iibku weli ma dhammaystirna: kaydka ma dhaco, deynna lama diiwaangelin. Milkiilaha oo keliya ayaa go\'aamin kara.',
              'Tap Send for Approval. The sale is not final yet: stock does not change and no debt is recorded. Only the owner can decide.',
            ),
          ),
          GuideStep(
            icon: Icons.rule_outlined,
            title: GuideText('Milkiiluhu wuu eegaa', 'Owner reviews'),
            body: GuideText('Milkiilaha ayaa fura Ansixinada, wuxuuna ansixiyaa ama didiaa codsiga.', 'The owner opens Approvals and approves or rejects the request.'),
            actor: GuideActor.owner,
          ),
          GuideStep(
            icon: Icons.thumb_up_outlined,
            title: GuideText('Haddii la ansixiyo', 'If approved'),
            body: GuideText('Kaydka ayaa hoos u dhacaya, deyntana waxaa lagu daraa hadhaaga macmiilka.', 'Stock goes down and the debt is added to the customer\'s balance.'),
            actor: GuideActor.app,
          ),
          GuideStep(
            icon: Icons.thumb_down_outlined,
            title: GuideText('Haddii la diido', 'If rejected'),
            body: GuideText('Iibka waa la joojiyaa; kaydka iyo deynta wax isbeddel ah ma yeelanayaan.', 'The sale is cancelled; stock and debt are left unchanged.'),
            actor: GuideActor.app,
          ),
        ],
      ),
    ],
  ),
  WorkflowGuide(
    id: 'returns_closing',
    icon: Icons.assignment_return_outlined,
    title: GuideText('Celin iyo xidhidhka lacagta', 'Returns and cash closing'),
    summary: GuideText('Laba habraac oo kala duwan', 'Two separate processes'),
    sequences: [
      GuideSequence(
        id: 'returns',
        title: GuideText('Celinta iibka', 'Sale return'),
        roles: _ownerManager,
        steps: [
          GuideStep(
            icon: Icons.receipt_long_outlined,
            title: GuideText('Fur rasiidka iibka', 'Open the sale receipt'),
            body: GuideText('Ka hel iibka la dhammeeyay oo fur rasiidkiisa.', 'Find the completed sale and open its receipt.'),
            actor: GuideActor.ownerOrManager,
          ),
          GuideStep(
            icon: Icons.undo_outlined,
            title: GuideText('Taabo Diiwaangeli Celin / Refund', 'Tap Record Return / Refund'),
            body: GuideText('Badhankan waxaa arka Milkiilaha iyo Maamuluhu oo keliya. Iibiyayaashu ma celin karaan.', 'Only the owner and managers see this button. Sellers cannot process returns.'),
            actor: GuideActor.ownerOrManager,
          ),
          GuideStep(
            icon: Icons.checklist_outlined,
            title: GuideText('Dooro alaabta iyo tirada', 'Select items and quantities'),
            body: GuideText('Dooro alaabta la celinayo. Tirada kama badnaan karto inta weli la celin karo.', 'Choose what is coming back. The quantity cannot be more than what is still returnable.'),
            actor: GuideActor.ownerOrManager,
          ),
          GuideStep(
            icon: Icons.currency_exchange_outlined,
            title: GuideText('Dooro habka celinta iyo sababta', 'Choose refund method and reason'),
            body: GuideText(
              'Lacag caddaan, bangi ama mobile. Ka-jarista deynta waxay u shaqaysaa iib deyn ah oo keliya. Sababta celinta waa loo baahan yahay.',
              'Cash, bank or mobile money. Credit adjustment works for credit sales only. A reason is required.',
            ),
            actor: GuideActor.ownerOrManager,
          ),
          GuideStep(
            icon: Icons.done_all,
            title: GuideText('Xaqiiji', 'Confirm'),
            body: GuideText('Kaydka, lacagta iyo warbixinnada waa la cusboonaysiiyaa.', 'Stock, money records and reports are updated.'),
            actor: GuideActor.app,
          ),
        ],
      ),
      GuideSequence(
        id: 'closing',
        title: GuideText('Xidhidhka lacagta', 'Cash closing'),
        roles: _allRoles,
        steps: [
          GuideStep(
            icon: Icons.savings_outlined,
            title: GuideText('Tiri lacagta', 'Count the cash'),
            body: GuideText('Dhammaadka maalinta, tiri lacagta caddaanka ah ee sanduuqa ku jirta.', 'At the end of the day, count the cash in the drawer.'),
          ),
          GuideStep(
            icon: Icons.upload_file_outlined,
            title: GuideText('Gudbi xidhidhka', 'Submit the closing'),
            body: GuideText(
              'Tabka Xirid ku geli lacagta aad tirisay. App-ku wuxuu u fiiriyaa lacagta la filayay.',
              'On the Close tab, enter the cash you counted. The app compares it with the expected cash.',
            ),
          ),
          GuideStep(
            icon: Icons.rule_outlined,
            title: GuideText('Milkiilaha ayaa dib u eegaya', 'Owner reviews'),
            body: GuideText('Milkiilaha ayaa ansixiya ama diida xidhidhka.', 'The owner approves or rejects the closing.'),
            actor: GuideActor.owner,
          ),
          GuideStep(
            icon: Icons.lock_outline,
            title: GuideText('Xidhidhka la ansixiyay waa dhamaystiran yahay', 'Approved closings are final'),
            body: GuideText('Xidhidh la ansixiyay dib looma qori karo.', 'An approved closing cannot be overwritten.'),
            actor: GuideActor.app,
          ),
        ],
      ),
    ],
  ),
];

List<WorkflowGuide> guidesForRole(String role) =>
    workflowGuides.where((g) => g.sequencesFor(role).isNotEmpty).toList();
