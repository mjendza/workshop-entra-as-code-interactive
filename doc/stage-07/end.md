# Stage 7: End & Cleanup

## Steps
- New in terraform? Review the terraform.tfstate file to see what resources are created and how they are structured.
- Run `terraform destroy` to remove all resources created in the previous stages.
- any issues? Remove the Access Package Assignment - We can't remove the package if there are any assignments.

## ⏱️ Estimated Time: 5 minutes

## Verification
- Visit https://portal.azure.com and review leftover resources.
- Check terraform state file to see if any resources are still present.

🎉 **Good Job! You have completed the workshop.** 🎉

---

## Stage Completion Checklist
- [ ] I have reviewed the terraform.tfstate file
- [ ] I have removed any Access Package assignments
- [ ] I have run `terraform destroy`
- [ ] I have verified all resources are removed in Azure Portal
- [ ] Workshop completed!

> **Tip:** Check all boxes above and close this issue to complete the workshop!

> **Report Issues:** Found a bug or have a question? [Report it here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues)

---
**Navigation:** [← Previous: Stage 6](../stage-06/pim.md) | [What's Next →](../stage-next/what-next.md) | [Final Solution](../stage-final/main.tf)