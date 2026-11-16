import json

from fastapi.testclient import TestClient

from navie.geocode.service import Geocoder, load, normalize
from navie.main import create_app
from navie.schemas import Place


def places() -> list[Place]:
    return [
        Place(
            name="Chợ Bến Thành",
            address="Lê Lợi, Quận 1",
            latlon=(10.7725, 106.6980),
            kind="marketplace",
        ),
        Place(
            name="Landmark 81",
            address="720A Điện Biên Phủ, Bình Thạnh",
            latlon=(10.7950, 106.7218),
            kind="building",
        ),
        Place(name="Nguyễn Trãi", latlon=(10.7700, 106.6900), kind="road"),
        Place(name="Nguyễn Trãi", latlon=(10.7550, 106.6750), kind="road"),
    ]


def test_normalize_expands_vietnamese_abbreviations() -> None:
    assert normalize("Chợ Bến Thành, Q. 1, TP.HCM") == (
        "cho ben thanh quan 1 thanh pho ho chi minh"
    )


def test_search_is_accent_insensitive() -> None:
    result = Geocoder(places()).search("cho ben thanh")
    assert result[0].name == "Chợ Bến Thành"


def test_near_ranks_the_closer_same_named_place_first() -> None:
    result = Geocoder(places()).search("nguyen trai", near=(10.7549, 106.6751))
    assert result[0].latlon == (10.7550, 106.6750)


def test_online_fallback_fills_missing_local_poi() -> None:
    landmark = Place(name="Landmark 81", latlon=(10.7950, 106.7218), kind="building")
    local = [Place(name="Hẻm 81", latlon=(10.80, 106.70), kind="road")]
    geocoder = Geocoder(local, online_search=lambda _query, _limit: [landmark])
    assert geocoder.search("landmark 81")[0] == landmark


def test_loads_generated_json_index(tmp_path) -> None:
    payload = {"places": [place.model_dump(mode="json") for place in places()]}
    (tmp_path / "hcmc_geocode.json").write_text(
        json.dumps(payload, ensure_ascii=False), encoding="utf-8"
    )
    assert load("hcmc", tmp_path).search("landmark")[0].name == "Landmark 81"


def test_geocode_endpoint_returns_places() -> None:
    client = TestClient(create_app(geocoder=Geocoder(places())))
    response = client.get("/v1/geocode", params={"q": "cho ben thanh"})
    assert response.status_code == 200
    assert response.json()[0]["name"] == "Chợ Bến Thành"


def test_geocode_endpoint_validates_near() -> None:
    client = TestClient(create_app(geocoder=Geocoder(places())))
    response = client.get("/v1/geocode", params={"q": "cho", "near": "not-a-point"})
    assert response.status_code == 422

def test_house_number_with_street_returns_address() -> None:
    geocoder = Geocoder(places())
    results = geocoder.search("123 nguyen trai")
    assert len(results) > 0
    assert "123" in results[0].name
    assert results[0].kind == "address"


def test_online_fallback_receives_near_coordinates() -> None:
    received: list[tuple[float, float] | None] = []

    def mock_online(query: str, limit: int, near: tuple[float, float] | None = None) -> list[Place]:
        received.append(near)
        return [Place(name="Highlands Coffee", latlon=(10.77, 106.70), kind="cafe")]

    local = [Place(name="Đường Hẻm", latlon=(10.80, 106.70), kind="road")]
    geocoder = Geocoder(local, online_search=mock_online)
    res = geocoder.search("highlands", near=(10.7769, 106.7009))
    assert len(res) > 0
    assert res[0].name == "Highlands Coffee"
    assert received == [(10.7769, 106.7009)]

