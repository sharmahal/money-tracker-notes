// Maps category -> subCategory -> list of lowercase keywords.
//
// ORDER MATTERS: the first match wins.
// - Grocery is before Food so "swiggy instamart" hits Grocery before Food's
//   generic "swiggy" keyword does.
// - Within each category, more specific sub-categories come first.

const Map<String, Map<String, List<String>>> _rules = {
  // ── Grocery ────────────────────────────────────────────────────────────────
  // Buying ingredients / household supplies.  Distinct from eating out (Food).
  'Grocery': {
    'Blinkit'          : ['blinkit'],
    'Zepto'            : ['zepto'],
    'Swiggy Instamart' : ['instamart'],          // checked before Food's 'swiggy'
    'BigBasket'        : ['bigbasket', 'big basket'],
    'JioMart'          : ['jiomart'],
    'Grofers'          : ['grofers'],
    'Milkbasket'       : ['milkbasket'],
    'Dunzo'            : ['dunzo'],
    'Licious'          : ['licious'],
    'DMart'            : ['dmart', 'd-mart', 'avenue supermarts'],
    'Reliance Fresh'   : ['reliance fresh', 'reliance smart'],
    'Nature Basket'    : ['nature basket'],
    'More Supermarket' : ['more supermarket', 'more retail'],
    'Big Bazaar'       : ['big bazaar', 'future retail'],
    'Metro Cash'       : ['metro cash', 'metro wholesale'],
    'Supermarket'      : ['supermarket', 'hypermarket', 'grocery', 'kirana'],
  },

  // ── Food ───────────────────────────────────────────────────────────────────
  // Eating / ordering food — restaurants, delivery, cafes.
  'Food': {
    'Zomato'           : ['zomato'],
    'Swiggy'           : ['swiggy'],             // catches swiggy food (instamart filtered above)
    "McDonald's"       : ['mcdonald', 'mcd '],
    'Dominos'          : ['domino'],
    'Pizza Hut'        : ['pizza hut'],
    'KFC'              : ['kfc'],
    'Burger King'      : ['burger king'],
    'Starbucks'        : ['starbucks'],
    'Cafe Coffee Day'  : ['cafe coffee day', 'ccd '],
    'Barista'          : ['barista'],
    'Subway'           : ['subway'],
    'Haldirams'        : ['haldiram'],
    'Restaurant'       : ['restaurant', 'dhaba', 'canteen', 'bistro', 'eatery',
                          'food court', 'bar & grill', 'bar and grill', 'tiffin'],
    'Bakery / Sweets'  : ['bakery', 'sweets', 'mithai', 'confectionery'],
    'Ice Cream'        : ['ice cream', 'baskin', 'naturals ice'],
    'Other Food'       : ['food', 'meal'],
  },

  // ── Essential ──────────────────────────────────────────────────────────────
  'Essential': {
    'Rent'             : ['rent', 'house rent', 'landlord', 'pg rent', 'accommodation'],
    'Electricity'      : ['electricity', 'msedcl', 'bescom', 'bses', 'tata power',
                          'adani electricity', 'torrent power', 'electric bill', 'power bill'],
    'Gas'              : ['gas bill', 'mahanagar gas', 'indane', 'hp gas',
                          'bharat gas', 'piped gas', 'gas cylinder'],
    'Water'            : ['water bill', 'bwssb', 'mcgm water', 'jal board', 'water supply'],
    'Internet/Mobile'  : ['airtel', 'jio', 'vodafone', 'vi ', 'bsnl', 'act fibernet',
                          'hathway', 'recharge', 'mobile bill', 'broadband', 'internet bill',
                          'tata sky', 'dish tv', 'sun direct'],
    'Insurance'        : ['lic ', 'hdfc life', 'icici pru', 'star health', 'care health',
                          'bajaj allianz', 'max life', 'insurance premium', 'policy premium',
                          'term plan', 'health insurance', 'motor insurance'],
    'EMI'              : ['emi', 'loan emi', 'home loan', 'car loan', 'personal loan',
                          'education loan', 'credit card emi'],
  },

  // ── Transport ──────────────────────────────────────────────────────────────
  'Transport': {
    'Uber'             : ['uber'],
    'Ola'              : ['olacabs', 'ola cab', 'ola auto', 'ola bike', 'ola electric'],
    'Rapido'           : ['rapido'],
    'InDrive'          : ['indrive'],
    'Metro'            : ['metro card', 'dmrc', 'bmrc', 'nmmc metro', 'metro rail', 'metro recharge'],
    'Fuel'             : ['petrol', 'diesel', 'iocl', 'hp petrol', 'bharat petroleum',
                          'bpcl', 'hpcl', 'fuel station', 'cng station', 'cng fill'],
    'Parking'          : ['parking', 'park+', 'fastag'],
    'Bus'              : ['ksrtc', 'msrtc', 'bus ticket', 'volvo bus'],
    'Auto/Taxi'        : ['taxi', 'prepaid cab'],
  },

  // ── Fun ────────────────────────────────────────────────────────────────────
  'Fun': {
    'Netflix'          : ['netflix'],
    'Amazon Prime'     : ['prime video', 'amazon prime'],
    'Hotstar'          : ['hotstar', 'disney+', 'disney plus', 'jiocinema'],
    'Spotify'          : ['spotify'],
    'YouTube'          : ['youtube premium'],
    'SonyLIV'          : ['sonyliv', 'sony liv'],
    'Apple'            : ['apple tv', 'apple music', 'app store'],
    'Movies'           : ['bookmyshow', 'pvr', 'inox', 'cinepolis', 'movie ticket'],
    'Gaming'           : ['steam', 'epic games', 'playstation', 'xbox',
                          'google play', 'garena', 'battlegrounds', 'game'],
    'Events'           : ['paytm insider', 'district by zomato', 'ticketmaster', 'allevents'],
  },

  // ── Shopping ───────────────────────────────────────────────────────────────
  'Shopping': {
    'Amazon'           : ['amazon.in', 'amazon pay later', 'amazon shopping', 'amazon'],
    'Flipkart'         : ['flipkart'],
    'Myntra'           : ['myntra'],
    'Meesho'           : ['meesho'],
    'Nykaa'            : ['nykaa'],
    'Ajio'             : ['ajio'],
    'Tata Cliq'        : ['tatacliq', 'tata cliq'],
    'Snapdeal'         : ['snapdeal'],
    'Ikea'             : ['ikea'],
    'Online Shopping'  : ['shopsy', 'e-commerce', 'online shopping'],
  },

  // ── Health ─────────────────────────────────────────────────────────────────
  'Health': {
    'Pharmacy'         : ['pharmacy', 'medplus', 'apollo pharmacy', '1mg',
                          'netmeds', 'pharmeasy', 'medical store', 'chemist', 'medicine'],
    'Hospital'         : ['hospital', 'nursing home', 'healthcare', 'health centre'],
    'Clinic'           : ['clinic', 'poly clinic'],
    'Doctor'           : ['doctor', 'dr. ', 'consultation fee', 'opd'],
    'Diagnostic'       : ['pathlab', 'diagnostic', 'thyrocare', 'dr lal',
                          'metropolis', 'lab test', 'blood test'],
    'Wellness'         : ['gym', 'cult fit', 'cure fit', 'yoga', 'fitness', 'wellness'],
  },

  // ── Travel ─────────────────────────────────────────────────────────────────
  'Travel': {
    'Flight'           : ['makemytrip', 'cleartrip', 'ixigo', 'goibibo',
                          'air india', 'indigo', 'spicejet', 'vistara', 'akasa', 'airlines'],
    'Hotel'            : ['oyo', 'treebo', 'fab hotels', 'marriott', 'taj hotel',
                          'oberoi', 'hotel booking', 'agoda', 'booking.com'],
    'Train'            : ['irctc', 'indian railway'],
    'Bus'              : ['redbus', 'abhibus', 'bus booking'],
  },

  // ── Investment ─────────────────────────────────────────────────────────────
  'Investment': {
    'Mutual Fund'      : ['mutual fund', ' sip', 'zerodha mf', 'groww',
                          'kuvera', 'paytm money', 'etmoney', 'coin zerodha'],
    'Stocks'           : ['zerodha', 'upstox', 'angel broking', 'motilal oswal',
                          'hdfc securities', 'iifl securities'],
    'Gold'             : ['sovereign gold', 'gold bond', 'gold etf', 'digital gold'],
    'FD/RD'            : ['fixed deposit', 'recurring deposit', 'fd open'],
  },
};

({String category, String subCategory}) categorize(String merchant, String description) {
  final text = '${merchant.toLowerCase()} ${description.toLowerCase()}';

  for (final catEntry in _rules.entries) {
    for (final subEntry in catEntry.value.entries) {
      for (final keyword in subEntry.value) {
        if (text.contains(keyword)) {
          return (category: catEntry.key, subCategory: subEntry.key);
        }
      }
    }
  }

  return (category: 'Others', subCategory: 'Miscellaneous');
}
