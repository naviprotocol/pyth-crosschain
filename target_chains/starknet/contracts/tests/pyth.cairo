use snforge_std::{
    declare, ContractClassTrait, start_prank, stop_prank, CheatTarget, spy_events, SpyOn, EventSpy,
    EventFetcher, event_name_hash, Event
};
use pyth::pyth::{
    IPythDispatcher, IPythDispatcherTrait, DataSource, Event as PythEvent, PriceFeedUpdateEvent
};
use pyth::reader::{ByteArray, ByteArrayImpl};
use pyth::util::{array_felt252_to_bytes31, UnwrapWithFelt252};
use core::starknet::ContractAddress;

fn decode_event(event: @Event) -> PythEvent {
    if *event.keys.at(0) == event_name_hash('PriceFeedUpdate') {
        assert!(event.keys.len() == 3);
        assert!(event.data.len() == 3);
        let event = PriceFeedUpdateEvent {
            price_id: u256 {
                low: (*event.keys.at(1)).try_into().unwrap(),
                high: (*event.keys.at(2)).try_into().unwrap(),
            },
            publish_time: (*event.data.at(0)).try_into().unwrap(),
            price: (*event.data.at(1)).try_into().unwrap(),
            conf: (*event.data.at(2)).try_into().unwrap(),
        };
        PythEvent::PriceFeedUpdate(event)
    } else {
        panic!("unrecognized event")
    }
}

#[test]
fn update_price_feeds_works() {
    let owner = 'owner'.try_into().unwrap();
    let wormhole = super::wormhole::deploy_and_init(owner);
    let pyth = deploy(
        owner,
        wormhole.contract_address,
        array![
            DataSource {
                emitter_chain_id: 26,
                emitter_address: 0xe101faedac5851e32b9b23b5f9411a8c2bac4aae3ed4dd7b811dd1a72ea4aa71,
            }
        ]
    );

    let mut spy = spy_events(SpyOn::One(pyth.contract_address));

    pyth.update_price_feeds(good_update1()).unwrap_with_felt252();

    spy.fetch_events();
    assert!(spy.events.len() == 1);
    let (from, event) = spy.events.at(0);
    assert!(from == @pyth.contract_address);
    let event = decode_event(event);
    let expected = PriceFeedUpdateEvent {
        price_id: 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43,
        publish_time: 1712589206,
        price: 7192002930010,
        conf: 3596501465,
    };
    assert!(event == PythEvent::PriceFeedUpdate(expected));

    let last_price = pyth
        .latest_price_info(0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43);
    assert!(last_price.price == 7192002930010);
    assert!(last_price.conf == 3596501465);
    assert!(last_price.expo == -8);
    assert!(last_price.publish_time == 1712589206);
    assert!(last_price.ema_price == 7181868900000);
    assert!(last_price.ema_conf == 4096812700);
}

fn deploy(
    owner: ContractAddress, wormhole_address: ContractAddress, data_sources: Array<DataSource>
) -> IPythDispatcher {
    let mut args = array![];
    (owner, wormhole_address, data_sources).serialize(ref args);
    let contract = declare("pyth");
    let contract_address = match contract.deploy(@args) {
        Result::Ok(v) => { v },
        Result::Err(err) => {
            panic(err.panic_data);
            0.try_into().unwrap()
        },
    };
    IPythDispatcher { contract_address }
}

// A random update pulled from Hermes.
fn good_update1() -> ByteArray {
    let bytes = array![
        141887862745809943100717722154781668316147089807066324001213790862261653767,
        451230040559159019530944948086670994623010697390864133264612902902585665886,
        355897384610106978643111834734000274494997301794613218547634257521495150151,
        140511063638834349363702006999356227863549404051701803148734324248522745879,
        435849190784772134907557391544163070978531038970298390345939133663347953446,
        416390591179833928094641114955594939466104495718036761707729297119441316151,
        360454929416220920336539568461651500076647166763464050800345920693176904002,
        316054999864337699543932294956493808847640383114707243342262764542081441331,
        325277902980160684959962429721294603784343718796390808940252812862355246813,
        43683235854839458868457367619068018785880460427473556950900276498953667,
        448289429405712011882317781416869052550573589492688760675666957663813001522,
        118081463902430977133121147164253483958565039026724621562859841189218059803,
        194064310618695309465615383754562031677972810736048112738513050109934134235,
        133901765334590923121691219814784557892214901646312752962904032795881821509,
        404227501001709279944936006741063968912686453006275462577777397594240621266,
        81649001731335394114026683805238949464016657447685509824621946636993704965,
        32402065226491532148674904435794801976788068837745943243341272676331333141,
        431262841416902409381606630149292665102873776020834630861578112749151562174,
        6164523115980545628843981978797257048781800754033825701059814297149591186,
        408761574582108996678203805090470134287794603493622537384530614829262728153,
        185368533577943244707350150853170361880334596276529206938783888784867529821,
        173578821500714074579643724957224629379984215847383417303110192934676518530,
        90209855380378362490166376523380463998928070428866100240907090599465187835,
        97758466908511588082569287391708453107999243934457382895073183209581711489,
        132725011490528489913736834798247512772139171145730373610858422315799224432,
        117123868005849140967825260063167768530251411611975150066586827543934313288,
        408149062252618928234854115279677715692278734600386004492580987016428761675,
        164529520317122600276020522906605877985809506451193373524142111430138855019,
        444793051809958482843529748761971363435331354795896511243191618771787268378,
        247660009137502548346315865368477795392972486141407800140910365553760622080,
        3281582060272565111592312037403686940429019548922889497694300188,
        93649805131515836129946966966350066506512123780266587069413066350925286142,
        394112423559676785086098106350541172262729583743734966358666094809121292390,
        35403101004688876764673991514113473446030702766599795822870037077688984558,
        99366103604611980443183454746643823071419076016677225828619807954313149423,
        10381657217606191031071521950784155484751645280452344547752823767622424055,
        391045354044274401116419632681482293741435113770205621235865697077178955228,
        311250087759201408758984550959714865999349469611700431708031036894849650573,
        59953730895385399344628932835545900304309851622811198425230584225200786697,
        226866843267230707879834616967256711063296411939069440476882347301771901839,
        95752383404870925303422787,
    ];
    ByteArrayImpl::new(array_felt252_to_bytes31(bytes), 11)
}
