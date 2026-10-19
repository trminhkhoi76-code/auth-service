# Duyệt policy JSON trước khi duyệt PR

Ví dụ độc lập với Terraform/CI/CD hiện có. Không gọi AWS, không sửa IAM.

## Luồng sử dụng

1. Tác giả mở PR sửa `examples/iam/policy.json`.
2. Người phụ trách policy đọc diff JSON tại đúng head commit, rồi tạo comment mới:
   `/approve-policy <full-head-commit-SHA>`.
3. Một người khác dùng **Review changes → Approve**, sau thời điểm comment trên.
4. Required status `policy/approval-order` chuyển success; native PR review rules cũng phải đạt trước merge.
5. Push lên main chạy workflow dry-run, in JSON/hash và lệnh put-role-policy minh họa.

Không có AWS credential hay OIDC trong hai workflow mới. `echo` không thực thi lệnh AWS.
Policy mẫu chỉ là ví dụ, không phải policy được đề xuất cho AWS account hiện tại.

## Cấu hình bắt buộc sau khi review PR cài đặt này

- Repository Settings → Secrets and variables → Actions → Variables:
  - `POLICY_APPROVERS`: danh sách GitHub login duyệt JSON, phân cách bằng dấu phẩy.
  - `POLICY_PR_APPROVERS`: danh sách GitHub login duyệt PR, phân cách bằng dấu phẩy.
- Cả hai nhóm phải có quyền write trở lên. Tác giả không được tự duyệt; hai bước phải do hai người khác nhau.
- Branch protection/ruleset trên main: require PR, ít nhất một approval, dismiss stale approvals,
  require conversation resolution, và required status `policy/approval-order` (nguồn GitHub Actions nếu UI cho phép).
  Bỏ bypass thông thường, áp dụng cho admin theo chính sách nhóm. Không bật merge queue cho ví dụ này.
- Bảo vệ `.github/workflows/**`, `.github/policy-gate/**`, và CODEOWNERS bằng code-owner review của nhóm quản trị.
  CODEOWNERS cần login/team thật nên ví dụ không tự gán owner.
- Chưa thay đổi setting repository, reviewer list hay AWS trong PR này.

## Bootstrap và chạy thử

Workflow đọc script từ main, không từ PR. Vì vậy **PR cài đặt này chưa tự chạy được gate mới**.
Sau khi review/merge phần cài đặt và cấu hình required check, tạo PR thử thay đổi policy JSON.
Có thể cần một lần chạy để status xuất hiện trong danh sách required checks.
Lưu ý: merge bất kỳ PR nào lên main cũng kích hoạt CI/CD Terraform/deploy sẵn có của repo;
workflow mới không thay đổi hành vi đó. Không merge PR cài đặt chỉ để thử nếu chưa muốn deploy ứng dụng.

Local: `node .github/policy-gate/evaluate.test.cjs`.

| Trường hợp | Kết quả |
| --- | --- |
| Chưa duyệt JSON | pending |
| PR approve trước JSON | pending; submit approval mới sau JSON |
| JSON approve rồi người khác approve PR tại cùng SHA | success |
| Có commit mới, kể cả chỉ sửa workflow | duyệt lại cả hai bước |
| Sửa/xóa comment JSON | comment đã sửa bị bỏ qua; tính lại gate |
| Dismiss PR approval | pending |
| Changes requested chưa được giải quyết | failure |
| Người ngoài allowlist/tác giả/bot tự duyệt | không được tính |

## Phạm vi và giới hạn

- Đây là custom comment gate thay cho Environment approval đã đề xuất ban đầu: dễ gắn approval trực tiếp với SHA và kiểm tra thứ tự bằng API.
- Validate JSON/cấu trúc tối thiểu, không chứng minh least privilege. Bổ sung IAM Access Analyzer/simulation trong triển khai thực.
- Chỉ hỗ trợ add/modify một file policy; xóa/rename hoặc file khác trong examples/iam bị chặn để cần thiết kế riêng.
- Lần duyệt JSON hợp lệ đầu tiên tại SHA được dùng; không có lệnh revoke riêng. Xóa comment để rút approval.
- Event xử lý bất đồng bộ: thay đổi review/comment có độ trễ trước khi status cập nhật.
  Native required reviews và dismiss stale approvals là lớp bảo vệ bổ sung bắt buộc.
- Người có quyền sửa settings hoặc xuất bản status có thể can thiệp gate. Với yêu cầu kiểm soát nghiêm ngặt,
  triển khai gate bằng GitHub App độc lập với required check source cố định, thay vì coi workflow mẫu là ranh giới bảo mật tuyệt đối.
- Event pull_request_review dùng workflow theo GitHub event semantics; không thực thi code từ head PR trong privileged script.
  Tuy vậy vẫn phải bảo vệ chính workflow bằng review/ruleset; checkout main một mình không bảo vệ workflow YAML bị sửa.
- Không thể chứng minh end-to-end trước khi cài workflow trên main và có hai reviewer thật.

## Khi chuyển sang apply thật

Tạo PR riêng: thay placeholder, dùng OIDC role chỉ có iam:PutRolePolicy trên role đích,
chỉ chạy sau merge vào main được bảo vệ, serialize các lần apply, và lưu SHA/hash vào audit log.
Không để workflow PR assume role có quyền ghi IAM. Ví dụ này cố ý không có công tắc bật apply thật.

Tham khảo: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
và https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
