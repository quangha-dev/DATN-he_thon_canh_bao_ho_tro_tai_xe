from evaluation.evaluate_agent_gold import semantic_similarity, tool_score


def test_tool_score_requires_expected_and_rejects_forbidden() -> None:
    assert tool_score(["list_completed_trips"], ["list_completed_trips"], []) == 1.0
    assert tool_score(["prepare_trip_action"], [], ["prepare_trip_action"]) == 0.0


def test_semantic_similarity_is_diacritic_insensitive() -> None:
    score = semantic_similarity(
        "Chuyến có thời điểm khởi hành sớm nhất được ưu tiên",
        "Chuyen co thoi diem khoi hanh som nhat duoc uu tien",
    )
    assert score > 0.99
